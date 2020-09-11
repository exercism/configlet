import sequtils, os, options, parsetoml, json

type
  ConfigJsonExercise = object
    slug: string

  ConfigJson = object
    exercises: seq[ConfigJsonExercise]

  TrackRepo* = object
    dir: string

  TrackExerciseTest* = object
    uuid: string
    enabled: bool

  TrackExerciseTests* = object
    canonicalData: seq[TrackExerciseTest]

  TrackExercise* = object
    slug*: string
    tests: Option[TrackExerciseTests]

  Track* = object
    exercises*: seq[TrackExercise]

proc parseConfigJson(filePath: string): ConfigJson =
  let json = json.parseFile(filePath)
  to(json, ConfigJson)

proc newTest(node: (string, TomlValueRef)): TrackExerciseTest =
  TrackExerciseTest(uuid: node[0], enabled: node[1].boolVal)

proc newTestsFromToml(toml: TomlValueRef): seq[TrackExerciseTest] =
  if toml.hasKey("canonical-tests"):
    toSeq(toml["canonical-tests"].getTable().pairs).map(newTest)
  else:
    @[]

proc tryParseTests(exerciseDir: string): Option[TrackExerciseTests] =
  let filePath = joinPath(exerciseDir, joinPath(".meta", "tests.toml"))
  
  if fileExists(filePath):
    let toml = parsetoml.parseFile(filePath)
    some(TrackExerciseTests(canonicalData: newTestsFromToml(toml)))
  else:
    none(TrackExerciseTests)

proc newTrackRepo: TrackRepo =
  TrackRepo(dir: getCurrentDir())

proc parseExercises(gitRepo: TrackRepo): seq[TrackExercise] =
  let configJsonFile = joinPath(gitRepo.dir, "config.json")  
  let configJson = parseConfigJson(configJsonFile)

  for exercise in configJson.exercises:
    let exerciseDir = joinPath(gitRepo.dir, joinPath("exercises", exercise.slug))
    let tests = tryParseTests(exerciseDir)
    result.add(TrackExercise(slug: exercise.slug, tests: tests))

proc newTrack(gitRepo: TrackRepo): Track =
  Track(exercises: parseExercises(gitRepo))

proc newTrack*: Track =
  let trackGitRepo = newTrackRepo()
  trackGitRepo.newTrack()
