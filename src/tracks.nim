import os, json, parsetoml

type
  ConfigJsonExercise = object
    slug: string

  ConfigJson = object
    exercises: seq[ConfigJsonExercise]

  TrackRepo = object
    dir: string

  TrackExerciseTest* = object
    uuid*: string
    enabled*: bool

  TrackExercise* = object
    slug*: string    
    case hasTests*: bool
    of true:
      tests*: seq[TrackExerciseTest]
    of false:
      discard

proc newTrackRepo: TrackRepo =
  let dir = getCurrentDir()
  TrackRepo(dir: dir)

proc parseConfigJson(filePath: string): ConfigJson =
  let json = json.parseFile(filePath)
  to(json, ConfigJson)

proc parseTrackExerciseTests(testsFile: string): seq[TrackExerciseTest] =
  let toml = parsetoml.parseFile(testsFile)
  if not toml.hasKey("canonical-tests"):
    return

  for uuid, enabled in toml["canonical-tests"].getTable():
    result.add(TrackExerciseTest(uuid: uuid, enabled: enabled.getBool()))

proc newTrackExercise(repo: TrackRepo, configExercise: ConfigJsonExercise): TrackExercise =
  let testsFile = joinPath(repo.dir, "exercises", configExercise.slug, ".meta", "tests.toml")

  if fileExists(testsFile):
    TrackExercise(slug: configExercise.slug, hasTests: true, tests: parseTrackExerciseTests(testsFile))
  else:
    TrackExercise(slug: configExercise.slug, hasTests: false)

proc findTrackExercises(repo: TrackRepo): seq[TrackExercise] =
  let configJson = parseConfigJson(joinPath(repo.dir, "config.json"))

  for configExercise in configJson.exercises:
    result.add(newTrackExercise(repo, configExercise))

proc findTrackExercises*: seq[TrackExercise] =
  let trackRepo = newTrackRepo()
  trackRepo.findTrackExercises()
