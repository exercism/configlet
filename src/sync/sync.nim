import std/[json, os, sequtils, sets, strformat, strutils]
import pkg/parsetoml
import ".."/[cli, logger]
import "."/[exercises, probspecs, sync_docs, sync_filepaths, update_tests]

proc isThisMetadataSynced(res: var seq[PathAndUpdatedJson]; conf: Conf; slug: string;
                          psMetadataTomlPath, trackExerciseConfigPath: string): bool =
  ## Returns `true` if the values of any `blurb`, `source` and `source_url` keys
  ## in `psMetadataTomlPath` are the same as those in `trackExerciseConfigPath`.
  ##
  ## Otherwise, appends to `res` if `conf.action.update` is `true`.
  if fileExists(psMetadataTomlPath):
    const keys = ["blurb", "source", "source_url"]
    if fileExists(trackExerciseConfigPath):
      let toml = parsetoml.parseFile(psMetadataTomlPath)
      var j = json.parseFile(trackExerciseConfigPath)
      var numTomlKeys = 0
      var numKeysAlreadyUpToDate = 0

      for key in keys:
        if toml.hasKey(key):
          inc numTomlKeys
          let upstreamVal = toml[key]
          if upstreamVal.kind == TomlValueKind.String:
            if j.hasKey(key):
              let trackVal = j[key]
              if trackVal.kind == JString and (upstreamVal.stringVal == trackVal.str):
                inc numKeysAlreadyUpToDate
              elif conf.action.update:
                j[key] = newJString(upstreamVal.stringVal)
          else:
            let msg = &"value of '{key}' is `{upstreamVal}`, but it must be a string"
            logNormal(&"[error] {msg}:\n{psMetadataTomlPath}")

      if numKeysAlreadyUpToDate == numTomlKeys:
        logDetailed(&"[skip] {slug}: metadata are up-to-date")
        result = true
      else:
        logNormal(&"[warn] {slug}: metadata are unsynced")
        if conf.action.update:
          res.add PathAndUpdatedJson(path: trackExerciseConfigPath,
                                     updatedJson: j)

    else:
      logNormal(&"[warn] {slug}: {trackExerciseConfigPath} is missing")
      if conf.action.update:
        let toml = parsetoml.parseFile(psMetadataTomlPath)
        var j = newJObject()
        for key in keys:
          if toml.hasKey(key):
            let upstreamVal = toml[key]
            if upstreamVal.kind == TomlValueKind.String:
              j[key] = newJString(upstreamVal.stringVal)
              res.add PathAndUpdatedJson(path: trackExerciseConfigPath,
                                         updatedJson: j)
  else:
    logNormal(&"[error] {slug}: {psMetadataTomlPath} is missing")

proc checkMetadata(exercises: seq[Exercise],
                   psExercisesDir: string,
                   trackPracticeExercisesDir: string,
                   seenUnsynced: var set[SyncKind],
                   conf: Conf): seq[PathAndUpdatedJson] =
  for exercise in exercises:
    let slug = exercise.slug.string
    let trackMetaDir = joinPath(trackPracticeExercisesDir, slug, ".meta")

    if dirExists(trackMetaDir):
      let psExerciseDir = psExercisesDir / slug
      if dirExists(psExerciseDir):
        const metadataFilename = "metadata.toml"
        const configFilename = "config.json"
        let psMetadataTomlPath = psExerciseDir / metadataFilename
        let trackExerciseConfigPath = trackMetaDir / configFilename
        if not isThisMetadataSynced(result, conf, slug, psMetadataTomlPath,
                                    trackExerciseConfigPath):
          seenUnsynced.incl skMetadata
      else:
        logDetailed(&"[skip] {slug}: does not exist in problem-specifications")
    else:
      logNormal(&"[error] {slug}: .meta dir missing")
      seenUnsynced.incl skMetadata

proc checkTests(exercises: seq[Exercise], seenUnsynced: var set[SyncKind]) =
  for exercise in exercises:
    let numMissing = exercise.tests.missing.len
    let wording = if numMissing == 1: "test case" else: "test cases"

    case exercise.status()
    of exOutOfSync:
      seenUnsynced.incl skTests
      logNormal(&"[warn] {exercise.slug}: missing {numMissing} {wording}")
      for testCase in exercise.testCases:
        if testCase.uuid in exercise.tests.missing:
          logNormal(&"       - {testCase.description} ({testCase.uuid})")
    of exInSync:
      logDetailed(&"[skip] {exercise.slug}: up-to-date")
    of exNoCanonicalData:
      logDetailed(&"[skip] {exercise.slug}: does not have canonical data")

proc explain(syncKind: SyncKind): string =
  case syncKind
  of skDocs: "have unsynced docs"
  of skFilepaths: "have unsynced filepaths"
  of skMetadata: "have unsynced metadata"
  of skTests: "are missing test cases"

proc userSaysYes(noun: string): bool =
  stderr.write &"sync the above {noun} ([y]es/[n]o)? "
  let resp = stdin.readLine().toLowerAscii()
  if resp == "y" or resp == "yes":
    result = true

proc sync*(conf: Conf) =
  logNormal("Checking exercises...")

  let probSpecsDir = initProbSpecsDir(conf)
  var seenUnsynced: set[SyncKind]

  try:
    let exercises = toSeq findExercises(conf, probSpecsDir)
    let psExercisesDir = probSpecsDir / "exercises"
    let trackExercisesDir = conf.trackDir / "exercises"
    let trackConceptExercisesDir = trackExercisesDir / "concept"
    let trackPracticeExercisesDir = trackExercisesDir / "practice"

    # Check/sync docs
    if skDocs in conf.action.scope:
      let sdPairs = checkDocs(exercises, psExercisesDir,
                              trackPracticeExercisesDir, seenUnsynced, conf)
      if sdPairs.len > 0:
        if conf.action.update:
          if conf.action.yes or userSaysYes("docs"):
            for sdPair in sdPairs:
              # TODO: don't replace first top-level header?
              # For example: the below currently writes `# Description`
              # instead of `# Instructions`
              copyFile(sdPair.source, sdPair.dest)

    # Check/sync filepaths
    if skFilepaths in conf.action.scope:
      let configPairs = checkFilepaths(conf, trackConceptExercisesDir,
                                       trackPracticeExercisesDir, seenUnsynced)
      if configPairs.len > 0: # Implies that `--update` was passed.
        if conf.action.yes or userSaysYes("filepaths"):
          for configPair in configPairs:
            writeFile(configPair.path,
                      configPair.updatedJson.pretty() & "\n")
          seenUnsynced.excl skFilepaths

    # Check/sync metadata
    if skMetadata in conf.action.scope:
      let configPairs = checkMetadata(exercises, psExercisesDir,
                                      trackPracticeExercisesDir, seenUnsynced,
                                      conf)
      if configPairs.len > 0: # Implies that `--update` was passed.
        if conf.action.yes or userSaysYes("metadata"):
          for pathAndUpdatedJson in configPairs:
            writeFile(pathAndUpdatedJson.path,
                      pathAndUpdatedJson.updatedJson.pretty() & "\n")
          seenUnsynced.excl skMetadata

    # Check/sync tests
    if skTests in conf.action.scope:
      if conf.action.update:
        updateTests(exercises, conf, seenUnsynced)
      else:
        checkTests(exercises, seenUnsynced)
  finally:
    if conf.action.probSpecsDir.len == 0:
      removeDir(probSpecsDir)

  if seenUnsynced.len > 0:
    for syncKind in seenUnsynced:
      logNormal(&"[warn] some exercises {explain(syncKind)}")
    quit(QuitFailure)
  else:
    if conf.action.scope == {SyncKind.low .. SyncKind.high}:
      logNormal("All exercises are up to date!")
    else:
      for syncKind in conf.action.scope:
        logNormal(&"All {syncKind} are up to date!")
    quit(QuitSuccess)
