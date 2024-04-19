import std/[options, os, strformat]
import ".."/[cli, helpers, sync/sync, types_track_config]
import "."/[approaches, articles, exercises]

proc create*(conf: Conf) =
  if conf.action.kind == actCreate:
    if conf.action.approachSlug.len > 0:
      if conf.action.exerciseCreate.len == 0:
        let msg = "Please specify an exercise to create an approach for, using --exercise <slug>"
        stderr.writeLine msg
        quit QuitFailure
      if conf.action.articleSlug.len > 0:
        let msg = &"Both --approach and --article were provided. Please specify only one."
        stderr.writeLine msg
        quit QuitFailure
      if conf.action.difficulty.isSome:
        let msg = "The difficulty argument is not supported for approaches"
        stderr.writeLine msg
        quit QuitFailure
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
          quit QuitFailure

      createApproach(Slug(conf.action.approachSlug), userExercise, exerciseDir)
    elif conf.action.articleSlug.len > 0:
      if conf.action.exerciseCreate.len == 0:
        let msg = "Please specify an exercise to create an article for, using --exercise <slug>"
        stderr.writeLine msg
        quit QuitFailure
      if conf.action.difficulty.isSome:
        let msg = "The difficulty argument is not supported for approaches"
        stderr.writeLine msg
        quit QuitFailure
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
          quit QuitFailure

      createArticle(Slug(conf.action.articleSlug), userExercise, exerciseDir)
    elif conf.action.conceptExerciseSlug.len > 0:
      if conf.action.difficulty.isSome:
        let msg = "The difficulty argument is not supported for concept exercises"
        stderr.writeLine msg
        quit QuitFailure

      createConceptExercise(conf)
    elif conf.action.practiceExerciseSlug.len > 0:
      createPracticeExercise(conf)
    else:
      let msg = "Please specify `--practice-exercise <slug>`, `--concept-exercise <slug>`, " &
                "`--article <slug>` or `--approach <slug>`"
      stderr.writeLine msg
      quit QuitFailure
  else:
    quit QuitFailure
