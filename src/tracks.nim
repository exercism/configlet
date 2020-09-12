import os, json, parsetoml, sets

type
  ConfigJsonExercise = object
    slug: string

  ConfigJson = object
    exercises: seq[ConfigJsonExercise]

  TrackRepoExercise = object
    dir: string

  TrackRepo = object
    dir: string

  TrackExerciseTests* = object
    included*: HashSet[string]
    excluded*: HashSet[string]

  TrackExercise* = object
    slug*: string
    tests*: TrackExerciseTests

proc newTrackRepo: TrackRepo =
  let dir = getCurrentDir()
  TrackRepo(dir: dir)

proc configJsonFile(repo: TrackRepo): string =
  joinPath(repo.dir, "config.json")

proc exercisesDir(repo: TrackRepo): string =
  joinPath(repo.dir, "exercises")

proc exerciseDir(repo: TrackRepo, exercise: ConfigJsonExercise): string =
  joinPath(repo.exercisesDir, exercise.slug)

proc slug(repoExercise: TrackRepoExercise): string =
  extractFilename(repoExercise.dir)

proc testsFile(repoExercise: TrackRepoExercise): string =
  joinPath(repoExercise.dir, ".meta", "tests.toml")

proc parseConfigJson(filePath: string): ConfigJson =
  let json = json.parseFile(filePath)
  to(json, ConfigJson)

proc newTrackRepoExercise(repo: TrackRepo, exercise: ConfigJsonExercise): TrackRepoExercise =
  TrackRepoExercise(dir: repo.exerciseDir(exercise))

proc exercises(repo: TrackRepo): seq[TrackRepoExercise] =
  let config = parseConfigJson(repo.configJsonFile)

  for exercise in config.exercises:
    result.add(newTrackRepoExercise(repo, exercise))

proc newTrackExerciseTests(repoExercise: TrackRepoExercise): TrackExerciseTests =
  if not fileExists(repoExercise.testsFile):
    return

  let tests = parsetoml.parseFile(repoExercise.testsFile)
  for uuid, enabled in tests["canonical-tests"].getTable():
    if enabled.getBool():
      result.included.incl(uuid)
    else:
      result.excluded.incl(uuid)

proc newTrackExercise(repoExercise: TrackRepoExercise): TrackExercise =
  TrackExercise(slug: repoExercise.slug, tests: newTrackExerciseTests(repoExercise))

proc findTrackExercises(repo: TrackRepo): seq[TrackExercise] =
  for repoExercise in repo.exercises:
    result.add(newTrackExercise(repoExercise))

proc findTrackExercises*: seq[TrackExercise] =
  let trackRepo = newTrackRepo()
  trackRepo.findTrackExercises()
