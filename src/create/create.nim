import std/[os, strformat]
import ".."/[cli, helpers, sync/sync, types_track_config]
import "."/[approaches, articles]

proc create*(conf: Conf) =
  if conf.action.kind == actCreate:
    if conf.action.exerciseCreate.len == 0:
      let msg = "please specify an exercise, using --exercise <slug>"
      showError(msg)
    if conf.action.approachSlug.len > 0:
      if conf.action.articleSlug.len > 0:
        let msg = &"both --approach and --article were provided. Please specify only one."
        showError(msg)
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
          let msg = &"the `-e, --exercise` option was used to specify an " &
                    &"exercise slug, but `{userExercise}` is not an slug in the " &
                    &"track config:\n{trackConfigPath}"
          showError(msg)

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
          let msg = &"the `-e, --exercise` option was used to specify an " &
                    &"exercise slug, but `{userExercise}` is not an slug in the " &
                    &"track config:\n{trackConfigPath}"
          showError(msg)

      createArticle(Slug(conf.action.articleSlug), userExercise, exerciseDir)
    else:
      let msg = "please specify `--article <slug>` or `--approach <slug>`"
      showError(msg)
  else:
    quit 1
