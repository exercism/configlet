import std/[sets, os, strformat]
import ".."/[cli, helpers, fmt/track_config, sync/probspecs, sync/sync, sync/sync_metadata, types_track_config, uuid/uuid]

proc createConceptExercise*(conf: Conf) =
  echo "create ce"

proc createPracticeExercise*(conf: Conf) =
  let trackConfigPath = conf.trackDir / "config.json"
  let trackConfig = parseFile(trackConfigPath, TrackConfig)
  let trackExerciseSlugs = getSlugs(trackConfig.exercises, conf, trackConfigPath)
  let userExercise = Slug(conf.action.exerciseCreate)

  if userExercise in trackExerciseSlugs.`concept`:
    let msg = &"There already is a concept exercise with `{userExercise}` " &
              &"in the track config:\n{trackConfigPath}"
    stderr.writeLine msg
    quit 1
  elif userExercise in trackExerciseSlugs.practice:
    let msg = &"There already is a practice exercise with `{userExercise}` " &
              &"in the track config:\n{trackConfigPath}"
    stderr.writeLine msg
    quit 1

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

  var a = trackConfig.exercises.practice
  a.add(exercise)

  trackConfig.exercises.practice = a;

  let prettied = prettyTrackConfig(trackConfig)
  writeFile(trackConfigPath, prettied)

  var scope: set[SyncKind]
  scope.incl(SyncKind.skDocs)
  scope.incl(SyncKind.skFilepaths)
  scope.incl(SyncKind.skMetadata)
  scope.incl(SyncKind.skTests)
  

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
