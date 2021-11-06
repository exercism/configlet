import std/[os, sequtils, strformat]
import ".."/[cli, logger]
import "."/[exercises, probspecs, sync_common, sync_docs, sync_filepaths,
           sync_metadata, sync_tests]

proc getSlugs(exercises: Exercises, conf: Conf,
              trackConfigPath: string): tuple[c: seq[Slug], p: seq[Slug]] =
  ## Returns the slugs of Concept Exercises and Practice Exercises in `exercises`.
  ## If `conf.action.exercise` has a non-zero length, returns only that one slug
  ## if the given exercise was found on the track.
  ##
  ## If the exercise was not found, prints an error and exits.
  result.c = getSlugs(exercises.`concept`)
  result.p = getSlugs(exercises.practice)
  let userExercise = Slug(conf.action.exercise)
  if userExercise.len > 0:
    if userExercise in result.c:
      result.c = @[userExercise]
      result.p.setLen 0
    elif userExercise in result.p:
      result.c.setLen 0
      result.p = @[userExercise]
    else:
      let msg = &"The `-e, --exercise` option was used to specify an " &
                &"exercise slug, but `{userExercise}` is not an slug in the " &
                &"track config:\n{trackConfigPath}"
      stderr.writeLine msg
      quit 1

proc syncImpl(conf: Conf): set[SyncKind] =
  let trackConfigPath = conf.trackDir / "config.json"
  let trackConfig = parseFile(trackConfigPath, TrackConfig)
  let (conceptExerciseSlugs, practiceExerciseSlugs) = getSlugs(trackConfig.exercises,
                                                               conf, trackConfigPath)

  # Don't clone problem-specifications if only `--filepaths` is given
  let probSpecsDir =
    if conf.action.scope == {skFilepaths}:
      ProbSpecsDir("not-a-real-directory")
    else:
      initProbSpecsDir(conf)

  try:
    let psExercisesDir = probSpecsDir / "exercises"
    let trackExercisesDir = conf.trackDir / "exercises"
    let trackPracticeExercisesDir = trackExercisesDir / "practice"

    for syncKind in conf.action.scope:
      case syncKind
      # Check/update docs
      of skDocs:
        checkOrUpdateDocs(result, conf, practiceExerciseSlugs,
                          trackPracticeExercisesDir, psExercisesDir)

      # Check/update metadata
      of skMetadata:
        checkOrUpdateMetadata(result, conf, practiceExerciseSlugs,
                              trackPracticeExercisesDir, psExercisesDir)

      # Check/update filepaths
      of skFilepaths:
        let trackConceptExercisesDir = trackExercisesDir / "concept"
        checkOrUpdateFilepaths(result, conf, conceptExerciseSlugs,
                               practiceExerciseSlugs, trackConfig.files,
                               trackPracticeExercisesDir, trackConceptExercisesDir)

      # Check/update tests
      of skTests:
        let exercises = toSeq findExercises(conf, probSpecsDir)
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
