import sequtils, os, options, parsetoml

type
  TrackGitRepo* = object
    dir: string

  TrackExerciseTest* = object
    uuid: string
    enabled: bool

  TrackExerciseTests* = object
    canonicalData: seq[TrackExerciseTest]

  TrackExercise* = object
    slug*: string
    tests: Option[TrackExerciseTests]

  TrackRepo* = object
    exercises*: seq[TrackExercise]

proc newTest(node: (string, TomlValueRef)): TrackExerciseTest =
  TrackExerciseTest(uuid: node[0], enabled: node[1].boolVal)

proc newTestsFromToml(toml: TomlValueRef): seq[TrackExerciseTest] =
  if toml.hasKey("canonical-tests"):
    toSeq(toml["canonical-tests"].getTable().pairs).map(newTest)
  else:
    @[]

proc tryNewTests(exerciseDir: string): Option[TrackExerciseTests] =
  let filePath = joinPath(exerciseDir, joinPath(".meta", "tests.toml"))
  
  if fileExists(filePath):
    let toml = parsetoml.parseFile(filePath)
    some(TrackExerciseTests(canonicalData: newTestsFromToml(toml)))
  else:
    none(TrackExerciseTests)

proc newTrackGitRepo: TrackGitRepo =
  TrackGitRepo(dir: getCurrentDir())

proc newExercise(exerciseDir: string): TrackExercise =
  let slug = extractFilename(exerciseDir)
  let tests = tryNewTests(exerciseDir)
  TrackExercise(slug: slug, tests: tests)

proc newTrackRepo(gitRepo: TrackGitRepo): TrackRepo =
  let exercisesDir = joinPath(gitRepo.dir, "exercises/*")
  let exercises = toSeq(walkDirs(exercisesDir)).map(newExercise)
  TrackRepo(exercises: exercises)

proc newTrackRepo*: TrackRepo =
  let trackGitRepo = newTrackGitRepo()
  trackGitRepo.newTrackRepo()
