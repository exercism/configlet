import std/[os, sequtils, strformat, strutils, terminal]
import pkg/jsony # This is not always used, but removing it will make tests fail.
import ".."/[cli, helpers, logger, types_track_config]
import "."/[exercises, probspecs, sync_common, sync_docs, sync_filepaths,
            sync_metadata, sync_tests]

proc validate(conf: Conf) =
  ## Exits with an error message if the given `conf` contains an invalid
  ## combination of options.
  if conf.action.update:
    if conf.action.yes and skTests in conf.action.scope and conf.action.tests == tmChoose:
      const msg = """
        '-y, --yes' was provided to non-interactively update, but tests are in
        the syncing scope and the tests updating mode is 'choose'.

        You can either:
        - use '--tests include' or '--tests exclude' to non-interactively include/exclude
          missing tests
        - or narrow the syncing scope via some combination of '--docs', '--filepaths', and
          '--metadata' (removing '--tests' if it was passed)
        - or remove '-y, --yes', and update by answering prompts

        If no syncing scope option is provided, configlet uses the full syncing scope.
        If '--tests' is provided without an argument, configlet uses the 'choose' mode.""".dedent(8)
      showError(msg)
    if not conf.action.yes and not isatty(stdin):
      let intersection = conf.action.scope * {skDocs, skFilepaths, skMetadata}
      if intersection.len > 0:
        const msg = """
          configlet ran in a non-interactive context, but interaction was required because
          '--update' was passed without '--yes', and at least one of docs, filepaths, and
          metadata were in the syncing scope.

          You can either:
          - keep using configlet non-interactively, and add the '--yes' option to perform
            changes without confirmation
          - or keep using configlet non-interactively, and remove the '--update' option so
            that configlet performs no changes
          - or run the same command in an interactive terminal, to update by answering
            prompts""".dedent(10)
        showError(msg)

type
  TrackExerciseSlugs* = object
    `concept`*: seq[Slug]
    practice*: seq[Slug]

func init*(T: typedesc[TrackExerciseSlugs], exercises: Exercises): T =
  T(
    `concept`: getSlugs(exercises.`concept`),
    practice: getSlugs(exercises.practice, withDeprecated = false)
  )

proc getSlugs*(exercises: Exercises, conf: Conf,
               trackConfigPath: string): TrackExerciseSlugs =
  ## Returns the slugs of Concept Exercises and Practice Exercises in
  ## `exercises`. If `conf.action.exercise(Fmt)` has a non-zero length, returns
  ## only that one slug if the given exercise was found on the track.
  ##
  ## If that exercise was not found, prints an error and exits.
  result = TrackExerciseSlugs.init(exercises)
  let userExercise =
    case conf.action.kind
    of actFmt:
      Slug(conf.action.exerciseFmt)
    of actSync:
      Slug(conf.action.exercise)
    else:
      Slug("")
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

  # Don't clone problem-specifications if only `--filepaths` is given
  let probSpecsDir =
    if conf.action.scope == {skFilepaths}:
      ProbSpecsDir("this_will_not_be_used")
    else:
      ProbSpecsDir.init(conf)

  let psExercisesDir = probSpecsDir / "exercises"
  let trackExercisesDir = conf.trackDir / "exercises"
  let trackPracticeExercisesDir = trackExercisesDir / "practice"

  logNormal("Checking exercises...")

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

func explain(syncKind: SyncKind): string =
  case syncKind
  of skDocs: "have unsynced docs"
  of skFilepaths: "have unsynced filepaths"
  of skMetadata: "have unsynced metadata"
  of skTests: "are missing test cases"

proc sync*(conf: Conf) =
  ## Checks/updates the data according to `conf`, and exits with 1 if we saw
  ## data that are still unsynced.
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
