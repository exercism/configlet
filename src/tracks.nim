import options, os, json, parsetoml, sets
import arguments

type
  ConfigJsonExercise = object
    slug: string

  ConfigJson = object
    exercises: seq[ConfigJsonExercise]

  TrackRepo = object
    dir: string

  TrackRepoExercise = object
    dir: string

  TrackExerciseTests* = object
    included*: HashSet[string]
    excluded*: HashSet[string]

  TrackExercise* = object
    slug*: string
    tests*: TrackExerciseTests
    repoExercise: TrackRepoExercise

proc newTrackRepo: TrackRepo =
  result.dir = getCurrentDir()

proc configJsonFile(repo: TrackRepo): string =
  repo.dir / "config.json"

proc exercisesDir(repo: TrackRepo): string =
  repo.dir / "exercises"

proc exerciseDir(repo: TrackRepo, exercise: ConfigJsonExercise): string =
  repo.exercisesDir / exercise.slug

proc slug(repoExercise: TrackRepoExercise): string =
  extractFilename(repoExercise.dir)

proc testsFile(repoExercise: TrackRepoExercise): string =
  repoExercise.dir / ".meta" / "tests.toml"

proc testsFile*(exercise: TrackExercise): string =
  exercise.repoExercise.testsFile

proc parseConfigJson(filePath: string): ConfigJson =
  let json = json.parseFile(filePath)
  to(json, ConfigJson)

proc newTrackRepoExercise(repo: TrackRepo, exercise: ConfigJsonExercise): TrackRepoExercise =
  result.dir = repo.exerciseDir(exercise)

proc exercises(repo: TrackRepo): seq[TrackRepoExercise] =
  let config = parseConfigJson(repo.configJsonFile)

  for exercise in config.exercises:
    result.add(newTrackRepoExercise(repo, exercise))

proc newTrackExerciseTests(repoExercise: TrackRepoExercise): TrackExerciseTests =
  if not fileExists(repoExercise.testsFile):
    return

  let tests = parsetoml.parseFile(repoExercise.testsFile)
  if not tests.hasKey("canonical-tests"):
    return

  for uuid, enabled in tests["canonical-tests"].getTable():
    if enabled.getBool():
      result.included.incl(uuid)
    else:
      result.excluded.incl(uuid)

proc newTrackExercise(repoExercise: TrackRepoExercise): TrackExercise =
  result.slug = repoExercise.slug
  result.tests = newTrackExerciseTests(repoExercise)

proc findTrackExercises(repo: TrackRepo, args: Arguments): seq[TrackExercise] =
  for repoExercise in repo.exercises:
    if args.exercise.isNone or args.exercise.get() == repoExercise.slug:
      result.add(newTrackExercise(repoExercise))

proc findTrackExercises*(args: Arguments): seq[TrackExercise] =
  let trackRepo = newTrackRepo()
  trackRepo.findTrackExercises(args)
