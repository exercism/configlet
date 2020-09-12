import os, json, parsetoml

type
  ConfigJsonExercise = object
    slug: string

  ConfigJson = object
    exercises: seq[ConfigJsonExercise]

  TrackRepoExercise = object
    dir: string

  TrackRepo = object
    dir: string

  TrackExerciseTest* = tuple[uuid: string, enabled: bool]

  TrackExercise* = object
    slug*: string  
    tests*: seq[TrackExerciseTest]

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

proc parseTrackExerciseTests(repoExercise: TrackRepoExercise): seq[TrackExerciseTest] =
  if not fileExists(repoExercise.testsFile):
    return

  let toml = parsetoml.parseFile(repoExercise.testsFile)
  for uuid, enabled in toml["canonical-tests"].getTable():
      result.add((uuid: uuid, enabled: enabled.getBool()))

proc newTrackExercise(repoExercise: TrackRepoExercise): TrackExercise =
  TrackExercise(slug: repoExercise.slug, tests: parseTrackExerciseTests(repoExercise))

proc findTrackExercises(repo: TrackRepo): seq[TrackExercise] =
  for repoExercise in repo.exercises:
    result.add(newTrackExercise(repoExercise))

proc findTrackExercises*: seq[TrackExercise] =
  let trackRepo = newTrackRepo()
  trackRepo.findTrackExercises()
