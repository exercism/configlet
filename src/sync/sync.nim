import std/[json, os, sequtils, strformat, strutils]
import ".."/[cli, logger]
import "."/[exercises, probspecs, sync_docs, sync_filepaths, sync_metadata,
            sync_tests]

proc userSaysYes(syncKind: SyncKind): bool =
  stderr.write &"sync the above {syncKind} ([y]es/[n]o)? "
  let resp = stdin.readLine().toLowerAscii()
  if resp == "y" or resp == "yes":
    result = true

proc update(configPairs: seq[PathAndUpdatedJson], conf: Conf,
            syncKind: SyncKind, seenUnsynced: var set[SyncKind]) =
  assert syncKind in {skFilepaths, skMetadata}
  if configPairs.len > 0: # Implies that `--update` was passed.
    if conf.action.yes or userSaysYes(syncKind):
      for configPair in configPairs:
        writeFile(configPair.path,
                  configPair.updatedJson.pretty() & "\n")
      seenUnsynced.excl syncKind

proc syncImpl(conf: Conf): set[SyncKind] =
  # Don't clone problem-specifications if only `--filepaths` is given
  let probSpecsDir =
    if conf.action.scope == {skFilepaths}:
      ProbSpecsDir("not-a-real-directory")
    else:
      initProbSpecsDir(conf)
  try:
    let exercises = toSeq findExercises(conf, probSpecsDir)
    let psExercisesDir = probSpecsDir / "exercises"
    let trackExercisesDir = conf.trackDir / "exercises"
    let trackPracticeExercisesDir = trackExercisesDir / "practice"

    for syncKind in conf.action.scope:
      case syncKind
      # Check/update docs
      of skDocs:
        let sdPairs = checkDocs(conf, result, trackPracticeExercisesDir,
                                exercises, psExercisesDir)
        if sdPairs.len > 0: # Implies that `--update` was passed.
          if conf.action.yes or userSaysYes(syncKind):
            for sdPair in sdPairs:
              # TODO: don't replace first top-level header?
              # For example: the below currently writes `# Description`
              # instead of `# Instructions`
              copyFile(sdPair.source, sdPair.dest)
            result.excl syncKind

      # Check/update filepaths
      of skFilepaths:
        let trackConceptExercisesDir = trackExercisesDir / "concept"
        let configPairs = checkFilepaths(conf, result, trackPracticeExercisesDir,
                                         trackConceptExercisesDir)
        update(configPairs, conf, syncKind, result)

      # Check/update metadata
      of skMetadata:
        let configPairs = checkMetadata(conf, result, trackPracticeExercisesDir,
                                        exercises, psExercisesDir)
        update(configPairs, conf, syncKind, result)

      # Check/update tests
      of skTests:
        if conf.action.update:
          updateTests(exercises, conf, result)
        else:
          checkTests(exercises, result)

  finally:
    if conf.action.probSpecsDir.len == 0 and conf.action.scope != {skFilepaths}:
      removeDir(probSpecsDir)

func explain(syncKind: SyncKind): string =
  case syncKind
  of skDocs: "have unsynced docs"
  of skFilepaths: "have unsynced filepaths"
  of skMetadata: "have unsynced metadata"
  of skTests: "are missing test cases"

proc sync*(conf: Conf) =
  logNormal("Checking exercises...")

  let seenUnsynced = syncImpl(conf)

  if seenUnsynced.len > 0:
    for syncKind in seenUnsynced:
      logNormal(&"[warn] some exercises {explain(syncKind)}")
    quit(QuitFailure)
  else:
    let userExercise = conf.action.exercise
    let wording =
      if userExercise.len > 0:
        &"The `{userExercise}` Practice Exercise"
      else:
        "Every Practice Exercise"
    if conf.action.scope == {SyncKind.low .. SyncKind.high}:
      logNormal(&"{wording} has up-to-date docs, filepaths, metadata, and tests!")
    else:
      for syncKind in conf.action.scope:
        logNormal(&"{wording} has up-to-date {syncKind}!")
    quit(QuitSuccess)
