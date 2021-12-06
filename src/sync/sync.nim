import std/[os, sequtils, strformat, strutils, terminal]
import ".."/[cli, logger]
import "."/[exercises, probspecs, sync_common, sync_docs, sync_filepaths,
            sync_metadata, sync_tests]

proc validate(conf: Conf) =
  ## Exits with an error message if the given `conf` contains an invalid
  ## combination of options.
  if conf.action.offline and conf.action.probSpecsDir.len == 0:
    showError(&"'{list(optSyncOffline)}' was given without passing " &
              &"'{list(optSyncProbSpecsDir)}'")
  if conf.action.update:
    if conf.action.yes and skTests in conf.action.scope:
      let msg = fmt"""
        '{list(optSyncYes)}' was provided to non-interactively update, but the tests updating mode is still 'choose'.
        You can either:
        - remove '{list(optSyncYes)}', and update by confirming prompts
        - or narrow the syncing scope via some combination of --docs, --filepaths, and --metadata
        - or add '--tests include' or '--tests exclude' to non-interactively include/exclude missing tests
        If no syncing scope option is provided, configlet uses the full syncing scope.
        If no --tests value is provided, configlet uses the 'choose' mode.""".unindent()
      showError(msg)
    if not isatty(stdin):
      if not conf.action.yes:
        let intersection = conf.action.scope * {skDocs, skFilepaths, skMetadata}
        if intersection.len > 0:
          let msg = fmt"""
            Configlet was used in a non-interactive context, and the --update option was passed without the --yes option
            You can either:
            - keep using configlet non-interactively, and remove the --update option so that no destructive changes are performed
            - keep using configlet non-interactively, and add the --yes option to perform destructive changes
            - use configlet in an interactive terminal""".unindent()
          showError(msg)

type
  TrackExerciseSlugs = object
    `concept`: seq[Slug]
    practice: seq[Slug]

func init(T: typedesc, exercises: Exercises): T =
  T(
    `concept`: getSlugs(exercises.`concept`),
    practice: getSlugs(exercises.practice)
  )

proc getSlugs(exercises: Exercises, conf: Conf,
              trackConfigPath: string): TrackExerciseSlugs =
  ## Returns the slugs of Concept Exercises and Practice Exercises in
  ## `exercises`. If `conf.action.exercise` has a non-zero length, returns only
  ## that one slug if the given exercise was found on the track.
  ##
  ## If that exercise was not found, prints an error and exits.
  result = TrackExerciseSlugs.init(exercises)
  let userExercise = Slug(conf.action.exercise)
  if userExercise.len > 0:
    if userExercise in result.`concept`:
      result.`concept` = @[userExercise]
      result.practice.setLen 0
    elif userExercise in result.practice:
      result.`concept`.setLen 0
      result.practice = @[userExercise]
    else:
      let msg = &"The `-e, --exercise` option was used to specify an " &
                &"exercise slug, but `{userExercise}` is not an slug in the " &
                &"track config:\n{trackConfigPath}"
      stderr.writeLine msg
      quit 1

proc syncImpl(conf: Conf): set[SyncKind] =
  ## Checks the data specified in `conf.action.scope`, and updates them if
  ## `--update` was passed and the user confirms.
  ##
  ## Returns a `set` of the still-unsynced `SyncKind`.
  let trackConfigPath = conf.trackDir / "config.json"
  let trackConfig = parseFile(trackConfigPath, TrackConfig)
  let trackExerciseSlugs = getSlugs(trackConfig.exercises, conf, trackConfigPath)
  logDetailed(&"Found {trackExerciseSlugs.`concept`.len} Concept Exercises " &
              &"and {trackExerciseSlugs.practice.len} Practice Exercises in " &
               trackConfigPath)
  logNormal("Checking exercises...")

  # Don't clone problem-specifications if only `--filepaths` is given
  let probSpecsDir =
    if conf.action.scope == {skFilepaths}:
      ProbSpecsDir("this_will_not_be_used")
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
        checkOrUpdateDocs(result, conf, trackExerciseSlugs.practice,
                          trackPracticeExercisesDir, psExercisesDir)

      # Check/update metadata
      of skMetadata:
        checkOrUpdateMetadata(result, conf, trackExerciseSlugs.practice,
                              trackPracticeExercisesDir, psExercisesDir)

      # Check/update filepaths
      of skFilepaths:
        let trackConceptExercisesDir = trackExercisesDir / "concept"
        checkOrUpdateFilepaths(result, conf, trackExerciseSlugs.`concept`,
                               trackExerciseSlugs.practice, trackConfig.files,
                               trackPracticeExercisesDir, trackConceptExercisesDir)

      # Check/update tests
      of skTests:
        let exercises = toSeq findExercises(conf, probSpecsDir)
        if conf.action.update:
          updateTests(result, conf, exercises)
        else:
          checkTests(result, exercises)

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
  ## Checks/updates the data according to `conf`, and exits with 1 if we saw
  ## data that is still unsynced.
  validate(conf)

  let seenUnsynced = syncImpl(conf)

  if seenUnsynced.len > 0:
    for syncKind in seenUnsynced:
      logNormal(&"[warn] some exercises {explain(syncKind)}")
    quit(QuitFailure)
  else:
    let userExercise = conf.action.exercise
    let wording =
      if userExercise.len > 0:
        &"The `{userExercise}` exercise"
      else:
        "Every exercise"
    if conf.action.scope == {SyncKind.low .. SyncKind.high}:
      logNormal(&"{wording} has up-to-date docs, filepaths, metadata, and tests!")
    else:
      for syncKind in conf.action.scope:
        logNormal(&"{wording} has up-to-date {syncKind}!")
    quit(QuitSuccess)
