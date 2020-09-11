import sequtils, os, options, parsetoml, json

type
  ConfigJsonExercise = object
    slug: string

  ConfigJson = object
    exercises: seq[ConfigJsonExercise]

  TrackRepoExercise = object
    dir: string
    slug: string
    testsFile: string

  TrackRepo* = object
    dir: string
    configFile: string
    exercises: seq[TrackRepoExercise]

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

proc newTrackRepoExercise(dir: string): TrackRepoExercise =
  TrackRepoExercise(
    dir: dir,
    slug: extractFilename(dir),
    testsFile: joinPath(dir, joinPath(".meta", "tests.toml"))
  )

proc newTrackRepoExercises(dir: string): seq[TrackRepoExercise] =
  for exerciseDir in walkDirs(joinPath(dir, "exercises/*")):
    result.add(newTrackRepoExercise(exerciseDir))

proc newTrackRepo: TrackRepo =
  let dir = getCurrentDir()
  let configFile = joinPath(dir, "config.json")
  let exercises = newTrackRepoExercises(dir)
  TrackRepo(dir: dir, configFile: configFile, exercises: exercises)

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

proc parseConfigJson(filePath: string): ConfigJson =
  let json = json.parseFile(filePath)
  to(json, ConfigJson)

proc parseExercises(repo: TrackRepo): seq[TrackExercise] =
  let configJson = parseConfigJson(repo.configFile)

  for exercise in configJson.exercises:
    let exerciseDir = joinPath(repo.dir, joinPath("exercises", exercise.slug))
    let tests = tryParseTests(exerciseDir)
    result.add(TrackExercise(slug: exercise.slug, tests: tests))


proc newTrack(gitRepo: TrackRepo): Track =
  Track(exercises: parseExercises(gitRepo))

proc newTrack*: Track =
  let trackGitRepo = newTrackRepo()
  trackGitRepo.newTrack()
