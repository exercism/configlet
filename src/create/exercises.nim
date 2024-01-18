import std/[sets, options, os, strformat]
import ".."/[cli, helpers, logger, fmt/track_config, sync/probspecs, sync/sync,
             sync/sync_filepaths, sync/sync_metadata, types_exercise_config,
             types_track_config, uuid/uuid]

proc verifyExerciseDoesNotExist(conf: Conf, slug: string): tuple[trackConfig: TrackConfig, trackConfigPath: string, exercise: Slug] =
  let trackConfigPath = conf.trackDir / "config.json"
  let trackConfig = parseFile(trackConfigPath, TrackConfig)
  let trackExerciseSlugs = getSlugs(trackConfig.exercises, conf, trackConfigPath)
  let userExercise = Slug(slug)

  if userExercise in trackExerciseSlugs.`concept`:
    let msg = &"There already is a concept exercise with `{userExercise}` as the slug " &
              &"in the track config:\n{trackConfigPath}"
    stderr.writeLine msg
    quit QuitFailure
  elif userExercise in trackExerciseSlugs.practice:
    let msg = &"There already is a practice exercise with `{userExercise}` as the slug " &
              &"in the track config:\n{trackConfigPath}"
    stderr.writeLine msg
    quit QuitFailure

  (trackConfig, trackConfigPath, userExercise)

proc createEmptyFile(file: string) =
  let fileDir = parentDir(file)
  if not dirExists(fileDir):
    createDir(fileDir)

  writeFile(file, "")

proc syncFiles(trackConfig: TrackConfig, trackDir: string, exerciseSlug: Slug, exerciseKind: ExerciseKind) =
  let exerciseDir = trackDir / "exercises" / $exerciseKind / $exerciseSlug

  let filePatternGroups = [
    trackConfig.files.solution,
    trackConfig.files.test,
    trackConfig.files.editor,
    trackConfig.files.invalidator,
    if exerciseKind == ekConcept: trackConfig.files.exemplar else: trackConfig.files.example
  ]

  for filePatterns in filePatternGroups:
    for filePattern in toFilepaths(filePatterns, exerciseSlug):
      createEmptyFile(exerciseDir / filePattern)

proc syncExercise(conf: Conf, slug: Slug,) =
  let syncConf = Conf(
    trackDir: conf.trackDir,
    action: Action(exercise: $slug, kind: actSync, update: true, yes: true,
                   offline: conf.action.offlineCreate,
                   scope: {skDocs, skFilepaths, skMetadata, skTests}, tests: tmInclude)
  )
  discard syncImpl(syncConf)

proc createFiles(conf: Conf, slug: Slug, trackConfig: TrackConfig, trackDir: string, exerciseKind: ExerciseKind) =
  withLevel(verQuiet):
    syncExercise(conf, slug)
    syncFiles(trackConfig, conf.trackDir, slug, exerciseKind)

proc createConceptExercise*(conf: Conf) =
  var (trackConfig, trackConfigPath, userExercise) = verifyExerciseDoesNotExist(conf, conf.action.conceptExerciseSlug)

  let probSpecsDir = ProbSpecsDir.init(conf)
  if dirExists(probSpecsDir / "exercises" / $userExercise):
    let msg = &"There already is an exercise with `{userExercise}` as the slug " &
              "in the problem specifications repo"
    stderr.writeLine msg
    quit QuitFailure

  let exercise = ConceptExercise(
    slug: userExercise,
    name: $userExercise, # TODO: Humanize slug
    uuid: $genUuid(),
    concepts: OrderedSet[string](),
    prerequisites: OrderedSet[string](),
    status: sMissing
  )

  trackConfig.exercises.`concept`.add(exercise)
  writeFile(trackConfigPath, prettyTrackConfig(trackConfig))

  let docsDir = conf.trackDir / "exercises" / "concept" / $userExercise / ".docs"
  createEmptyFile(docsDir / "introduction.md")
  createEmptyFile(docsDir / "instructions.md")

  createFiles(conf, userExercise, trackConfig, conf.trackDir, ekConcept)

  logNormal(&"Created concept exercise '{userExercise}'.")

proc createPracticeExercise*(conf: Conf) =
  var (trackConfig, trackConfigPath, userExercise) = verifyExerciseDoesNotExist(conf, conf.action.practiceExerciseSlug)

  let probSpecsDir = ProbSpecsDir.init(conf)
  let metadataFile = probSpecsDir / "exercises" / $userExercise / "metadata.toml"
  let metadata =
    if fileExists(metadataFile):
      parseMetadataToml(metadataFile)
    else:
      UpstreamMetadata(title: $userExercise, blurb: "", source: none(string), source_url: none(string))

  let exercise = PracticeExercise(
    slug: userExercise,
    name: metadata.title,
    uuid: $genUuid(),
    practices: OrderedSet[string](),
    prerequisites: OrderedSet[string](),
    difficulty: 1,
    status: sMissing
  )

  trackConfig.exercises.practice.add(exercise)
  writeFile(trackConfigPath, prettyTrackConfig(trackConfig))

  let docsDir = conf.trackDir / "exercises" / "practice" / $userExercise / ".docs"
  createEmptyFile(docsDir / "instructions.md")

  createFiles(conf, userExercise, trackConfig, conf.trackDir, ekPractice)

  logNormal(&"Created practice exercise '{userExercise}'.")
