import std/[json, os, sets]
import pkg/parsetoml
import ".."/cli

type
  ConfigJsonExercise = object
    slug: string

  ConfigJson = object
    practice: seq[ConfigJsonExercise]

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

func configJsonFile(repo: TrackRepo): string =
  repo.dir / "config.json"

func exercisesDir(repo: TrackRepo): string =
  repo.dir / "exercises"

func practiceExerciseDir(repo: TrackRepo, exercise: ConfigJsonExercise): string =
  repo.exercisesDir / "practice" / exercise.slug

func slug(exercise: TrackRepoExercise): string =
  extractFilename(exercise.dir)

func testsFile(exercise: TrackRepoExercise): string =
  exercise.dir / ".meta" / "tests.toml"

func testsFile*(exercise: TrackExercise): string =
  exercise.repoExercise.testsFile

proc parseConfigJson(filePath: string): ConfigJson =
  let json = json.parseFile(filePath)["exercises"]
  to(json, ConfigJson)

func initTrackRepoExercise(repo: TrackRepo,
    exercise: ConfigJsonExercise): TrackRepoExercise =
  TrackRepoExercise(dir: repo.practiceExerciseDir(exercise))

proc exercises(repo: TrackRepo): seq[TrackRepoExercise] =
  let config = parseConfigJson(repo.configJsonFile)

  for exercise in config.practice:
    result.add(initTrackRepoExercise(repo, exercise))

proc newTrackExerciseTests(exercise: TrackRepoExercise): TrackExerciseTests =
  if not fileExists(exercise.testsFile):
    return

  let tests = parsetoml.parseFile(exercise.testsFile)

  for uuid, val in tests.getTable():
    if val.hasKey("include"):
      if val["include"].kind == Bool:
        let isIncluded = val["include"].getBool()
        if isIncluded:
          result.included.incl(uuid)
        else:
          result.excluded.incl(uuid)
      else:
        let msg = "Error: the value of an `include` key is `" &
                  val["include"].toTomlString() & "`, but it must be a bool:\n" &
                  exercise.testsFile()
        stderr.writeLine(msg)
    else:
      result.included.incl(uuid)

proc newTrackExercise(exercise: TrackRepoExercise): TrackExercise =
  TrackExercise(
    slug: exercise.slug,
    tests: newTrackExerciseTests(exercise),
  )

proc findTrackExercises(repo: TrackRepo, conf: Conf): seq[TrackExercise] =
  for repoExercise in repo.exercises:
    if conf.action.exercise.len == 0 or conf.action.exercise == repoExercise.slug:
      result.add(newTrackExercise(repoExercise))

proc findTrackExercises*(conf: Conf): seq[TrackExercise] =
  let trackRepo = TrackRepo(dir: conf.trackDir)
  trackRepo.findTrackExercises(conf)
