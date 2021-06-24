import std/[json, os, sequtils, strformat, strutils]
import ".."/[cli, logger]
import "."/[exercises, probspecs, sync_docs, sync_filepaths, sync_metadata,
            sync_tests]

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
