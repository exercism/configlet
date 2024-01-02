import std/[sets, os, strformat]
import ".."/[cli, helpers, fmt/track_config, sync/probspecs, sync/sync, sync/sync_filepaths, sync/sync_metadata, types_exercise_config, types_track_config, uuid/uuid]

proc verifyExerciseDoesNotExist(conf: Conf): tuple[trackConfig: TrackConfig, trackConfigPath: string, exercise: Slug] =
  let trackConfigPath = conf.trackDir / "config.json"
  let trackConfig = parseFile(trackConfigPath, TrackConfig)
  let trackExerciseSlugs = getSlugs(trackConfig.exercises, conf, trackConfigPath)
  let userExercise = Slug(conf.action.exerciseCreate)

  if userExercise in trackExerciseSlugs.`concept`:
    let msg = &"There already is a concept exercise with `{userExercise}` as the slug " &
              &"in the track config:\n{trackConfigPath}"
    stderr.writeLine msg
    quit 1
  elif userExercise in trackExerciseSlugs.practice:
    let msg = &"There already is a practice exercise with `{userExercise}` as the slug " &
              &"in the track config:\n{trackConfigPath}"
    stderr.writeLine msg
    quit 1

  (trackConfig, trackConfigPath, userExercise)

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
      writeFile(exerciseDir / filePattern, "")

proc syncExercise(conf: Conf, scope: set[SyncKind]) =
  let syncConf = Conf(
    trackDir: conf.trackDir,
    
    action: Action(
      exercise: conf.action.exerciseCreate,
      kind: actSync,
      scope: scope,
      update: true,
      yes: true,
      tests: tmInclude
    )
  )
  discard syncImpl(syncConf, log = false)

proc createConceptExercise*(conf: Conf) =
  var (trackConfig, trackConfigPath, userExercise) = verifyExerciseDoesNotExist(conf)

  let probSpecsDir = ProbSpecsDir.init(conf)
  if dirExists(probSpecsDir / "exercises" / $userExercise):
    let msg = &"There already is an exercise with `{userExercise}` as the slug " &
              "in the problem specifications repo"
    stderr.writeLine msg
    quit 1

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

  syncExercise(conf, {skMetadata, skFilepaths})

  let docsDir = conf.trackDir / "exercises" / "concept" / $userExercise / ".docs"
  if not dirExists(docsDir):
    createDir(docsDir)

  writeFile(docsDir / "introduction.md", "")
  writeFile(docsDir / "instructions.md", "")

  syncFiles(trackConfig, conf.trackDir, userExercise, ekConcept)

proc createPracticeExercise*(conf: Conf) =
  var (trackConfig, trackConfigPath, userExercise) = verifyExerciseDoesNotExist(conf)

  let probSpecsDir = ProbSpecsDir.init(conf)
  let metadata = parseMetadataToml(probSpecsDir / "exercises" / $userExercise / "metadata.toml")

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

  syncExercise(conf, {skDocs, skFilepaths, skMetadata, skTests})
  syncFiles(trackConfig, conf.trackDir, userExercise, ekPractice)
