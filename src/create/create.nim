import std/[os, strformat]
import ".."/[cli, helpers, sync/sync, types_track_config]
import "."/[approaches, articles]

proc create*(conf: Conf) =
  if conf.action.kind == actCreate:
    if conf.action.approachSlug.len > 0:
      let trackConfigPath = conf.trackDir / "config.json"
      let trackConfig = parseFile(trackConfigPath, TrackConfig)
      let trackExerciseSlugs = getSlugs(trackConfig.exercises, conf, trackConfigPath)
      let userExercise = Slug(conf.action.exerciseCreate)

      let exerciseDir =
        if userExercise in trackExerciseSlugs.`concept`:
          conf.trackDir / "exercises" / "concept" / $userExercise
        elif userExercise in trackExerciseSlugs.practice:
          conf.trackDir / "exercises" / "practice" / $userExercise
        else:
          let msg = &"The `-e, --exercise` option was used to specify an " &
                    &"exercise slug, but `{userExercise}` is not an slug in the " &
                    &"track config:\n{trackConfigPath}"
          stderr.writeLine msg
          quit 1

      createApproach(Slug(conf.action.approachSlug), userExercise, exerciseDir)
    elif conf.action.articleSlug.len > 0:
      let trackConfigPath = conf.trackDir / "config.json"
      let trackConfig = parseFile(trackConfigPath, TrackConfig)
      let trackExerciseSlugs = getSlugs(trackConfig.exercises, conf, trackConfigPath)
      let userExercise = Slug(conf.action.exerciseCreate)

      let exerciseDir =
        if userExercise in trackExerciseSlugs.`concept`:
          conf.trackDir / "exercises" / "concept" / $userExercise
        elif userExercise in trackExerciseSlugs.practice:
          conf.trackDir / "exercises" / "practice" / $userExercise
        else:
          let msg = &"The `-e, --exercise` option was used to specify an " &
                    &"exercise slug, but `{userExercise}` is not an slug in the " &
                    &"track config:\n{trackConfigPath}"
          stderr.writeLine msg
          quit 1

      createArticle(Slug(conf.action.articleSlug), userExercise, exerciseDir)
    else:
      quit 1
  else:
    quit 1
