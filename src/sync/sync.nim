import std/[json, os, sequtils, sets, strformat, strutils]
import pkg/parsetoml
import ".."/[cli, logger]
import "."/[exercises, probspecs, update_tests]

proc contentsAfterFirstHeader(path: string): string =
  result = newStringOfCap(getFileSize(path))
  var isFirstLine = true
  for line in path.lines:
    if isFirstLine:
      if not (line.len > 2 and line[0] == '#' and line[1] == ' '):
        result.add line
        result.add '\n'
      isFirstLine = false
    else:
      result.add line
      result.add '\n'

type
  SourceDestPair = object
    source: string
    dest: string

proc checkFilesIdentical(source, dest, slug, filename: string;
                         seenUnsynced: var set[SyncKind];
                         conf: Conf;
                         sdPairs: var seq[SourceDestPair]) =
  ## Prints a message that describes whether the files at `source` and `dest`
  ## have identical contents.
  if contentsAfterFirstHeader(source) == contentsAfterFirstHeader(dest):
    logDetailed(&"[skip] {slug}: {filename} is up-to-date")
  else:
    logNormal(&"[warn] {slug}: {filename} is unsynced")
    seenUnsynced.incl skDocs
    if conf.action.update:
      sdPairs.add SourceDestPair(source: source, dest: dest)

proc checkDocs(exercises: seq[Exercise],
               psExercisesDir: string,
               trackPracticeExercisesDir: string,
               seenUnsynced: var set[SyncKind],
               conf: Conf): seq[SourceDestPair] =
  for exercise in exercises:
    let slug = exercise.slug.string
    let trackDocsDir = joinPath(trackPracticeExercisesDir, slug, ".docs")

    if dirExists(trackDocsDir):
      let psExerciseDir = psExercisesDir / slug
      if dirExists(psExerciseDir):

        # If the exercise in problem-specifications has an `introduction.md`
        # file, the track exercise must have a `.docs/introduction.md` file.
        let introFilename = "introduction.md"
        let psIntroPath = psExerciseDir / introFilename
        if fileExists(psIntroPath):
          let trackIntroPath = trackDocsDir / introFilename
          if fileExists(trackIntroPath):
            checkFilesIdentical(psIntroPath, trackIntroPath, slug,
                               introFilename, seenUnsynced, conf, result)
          else:
            logNormal(&"[error] {slug}: {introFilename} is missing")
            seenUnsynced.incl skDocs

        # The track exercise must have a `.docs/instructions.md` file.
        # Its contents should match those of the corresponding `instructions.md`
        # file in problem-specifications (or `description.md` if that file
        # doesn't exist).
        let instrFilename = "instructions.md"
        let trackInstrPath = trackDocsDir / instrFilename
        if fileExists(trackInstrPath):
          let descFilename = "description.md"
          let psInstrPath = psExerciseDir / instrFilename
          let psDescPath = psExerciseDir / descFilename
          if fileExists(psInstrPath):
            checkFilesIdentical(psInstrPath, trackInstrPath, slug,
                               instrFilename, seenUnsynced, conf, result)
          elif fileExists(psDescPath):
            checkFilesIdentical(psDescPath, trackInstrPath, slug,
                                instrFilename, seenUnsynced, conf, result)
          else:
            logNormal(&"[error] {slug}: does not have an upstream " &
                      &"{instrFilename} or {descFilename} file")
            seenUnsynced.incl skDocs
        else:
          logNormal(&"[error] {slug}: {instrFilename} is missing")
          seenUnsynced.incl skDocs

      else:
        logDetailed(&"[skip] {slug}: does not exist in problem-specifications")
    else:
      logNormal(&"[error] {slug}: .docs dir missing")
      seenUnsynced.incl skDocs

proc checkFilepaths(exercises: seq[Exercise], seenUnsynced: var set[SyncKind]) =
  if false:
    seenUnsynced.incl skFilepaths

type
  MetadataPair = object
    trackJsonPath: string
    updatedJson: JsonNode

proc checkMetadata(exercises: seq[Exercise],
                   psExercisesDir: string,
                   trackPracticeExercisesDir: string,
                   seenUnsynced: var set[SyncKind],
                   conf: Conf): seq[MetadataPair] =
  for exercise in exercises:
    let slug = exercise.slug.string
    let trackMetaDir = joinPath(trackPracticeExercisesDir, slug, ".meta")

    if dirExists(trackMetaDir):
      let psExerciseDir = psExercisesDir / slug
      if dirExists(psExerciseDir):

        let metadataFilename = "metadata.toml"
        let psMetadataTomlPath = psExerciseDir / metadataFilename
        if fileExists(psMetadataTomlPath):
          let trackExerciseConfigPath = trackMetaDir / "config.json"
          if fileExists(trackExerciseConfigPath):
            let toml = parsetoml.parseFile(psMetadataTomlPath)
            var j = json.parseFile(trackExerciseConfigPath)
            const keys = ["blurb", "source", "source_url"]
            for key in keys:
              if toml.hasKey(key):
                let upstreamVal = toml[key]
                if upstreamVal.kind == TomlValueKind.String:
                  if j.hasKey(key):
                    let trackVal = j[key]
                    if trackVal.kind == JString:
                      if upstreamVal.stringVal == trackVal.str:
                        logDetailed(&"[skip] {slug}: metadata is up-to-date")
                      else:
                        logNormal(&"[warn] {slug}: metadata is unsynced")
                        seenUnsynced.incl skMetadata
                        if conf.action.update:
                          j[key].str = upstreamVal.stringVal
                          result.add MetadataPair(
                            trackJsonPath: trackExerciseConfigPath,
                            updatedJson: j)
                else:
                  seenUnsynced.incl skMetadata
          else:
            logNormal(&"[error] {slug}: {metadataFilename} is missing")
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
    let trackPracticeExercisesDir = joinPath(conf.trackDir, "exercises", "practice")

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

    if skFilepaths in conf.action.scope:
      checkFilepaths(exercises, seenUnsynced)

    if skMetadata in conf.action.scope:
      let metadataPairs = checkMetadata(exercises, psExercisesDir,
                                        trackPracticeExercisesDir, seenUnsynced,
                                        conf)
      if metadataPairs.len > 0:
        if conf.action.update:
          if conf.action.yes or userSaysYes("metadata"):
            for metadataPair in metadataPairs:
              writeFile(metadataPair.trackJsonPath,
                        metadataPair.updatedJson.pretty() & "\n")

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
