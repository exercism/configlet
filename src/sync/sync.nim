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

proc userSaysYes(syncKind: SyncKind): bool =
  stderr.write &"sync the above {syncKind} ([y]es/[n]o)? "
  let resp = stdin.readLine().toLowerAscii()
  if resp == "y" or resp == "yes":
    result = true

proc update(configPairs: seq[PathAndUpdatedJson], conf: Conf,
            syncKind: SyncKind, seenUnsynced: var set[SyncKind]) =
  if configPairs.len > 0: # Implies that `--update` was passed.
    if conf.action.yes or userSaysYes(syncKind):
      for configPair in configPairs:
        writeFile(configPair.path,
                  configPair.updatedJson.pretty() & "\n")
      seenUnsynced.excl syncKind

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

    for syncKind in conf.action.scope:
      case syncKind
      # Check/sync docs
      of skDocs:
        let sdPairs = checkDocs(exercises, psExercisesDir,
                                trackPracticeExercisesDir, seenUnsynced, conf)
        if sdPairs.len > 0: # Implies that `--update` was passed.
          if conf.action.yes or userSaysYes(syncKind):
            for sdPair in sdPairs:
              # TODO: don't replace first top-level header?
              # For example: the below currently writes `# Description`
              # instead of `# Instructions`
              copyFile(sdPair.source, sdPair.dest)
            seenUnsynced.excl syncKind

      # Check/sync filepaths
      of skFilepaths:
        let configPairs = checkFilepaths(conf, trackConceptExercisesDir,
                                         trackPracticeExercisesDir, seenUnsynced)
        update(configPairs, conf, syncKind, seenUnsynced)

      # Check/sync metadata
      of skMetadata:
        let configPairs = checkMetadata(exercises, psExercisesDir,
                                        trackPracticeExercisesDir, seenUnsynced,
                                        conf)
        if configPairs.len > 0: # Implies that `--update` was passed.
          if conf.action.yes or userSaysYes(syncKind):
            for pathAndUpdatedJson in configPairs:
              writeFile(pathAndUpdatedJson.path,
                        pathAndUpdatedJson.updatedJson.pretty() & "\n")
            seenUnsynced.excl syncKind

      # Check/sync tests
      of skTests:
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
