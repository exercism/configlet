import std/[sets, os, strformat]
import ".."/[cli, helpers, fmt/track_config, sync/sync, types_track_config, uuid/uuid]

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

  let exerciseDir = conf.trackDir / "exercises" / "practice" / $userExercise
  let exercise = PracticeExercise(
    slug: userExercise,
    name: $userExercise,
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
