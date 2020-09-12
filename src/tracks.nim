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

proc newTrackRepoExercise(dir: string): TrackRepoExercise =
  TrackRepoExercise(dir: dir)

proc configJsonFile(repo: TrackRepo): string =
  joinPath(repo.dir, "config.json")

proc exercisesDir(repo: TrackRepo): string =
  joinPath(repo.dir, "exercises")

proc exercises(repo: TrackRepo): seq[TrackRepoExercise] =
  for exerciseDir in walkDirs(joinPath(repo.exercisesDir, "*")):
    result.add(newTrackRepoExercise(exerciseDir))

proc parseConfigJson(filePath: string): ConfigJson =
  let json = json.parseFile(filePath)
  to(json, ConfigJson)

proc parseTrackExerciseTests(testsTable: TomlTableRef): seq[TrackExerciseTest] =
  for uuid, enabled in testsTable:
    result.add((uuid: uuid, enabled: enabled.getBool()))

proc parseTrackExerciseTests(testsFile: string): seq[TrackExerciseTest] =
  let toml = parsetoml.parseFile(testsFile)
  if not toml.hasKey("canonical-tests"):
    return

  parseTrackExerciseTests(toml["canonical-tests"].getTable())

proc newTrackExercise(repo: TrackRepo, configExercise: ConfigJsonExercise): TrackExercise =
  let testsFile = joinPath(repo.dir, "exercises", configExercise.slug, ".meta", "tests.toml")

  if fileExists(testsFile):
    TrackExercise(slug: configExercise.slug, tests: parseTrackExerciseTests(testsFile))
  else:
    TrackExercise(slug: configExercise.slug, tests: @[])

proc findTrackExercises(repo: TrackRepo): seq[TrackExercise] =
  let configJson = parseConfigJson(repo.configJsonFile)

  for configExercise in configJson.exercises:
    result.add(newTrackExercise(repo, configExercise))

proc findTrackExercises*: seq[TrackExercise] =
  let trackRepo = newTrackRepo()
  trackRepo.findTrackExercises()
