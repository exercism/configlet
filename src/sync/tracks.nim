import std/[json, os, sets]
import pkg/parsetoml
import ".."/cli

type
  ConfigJsonExercise = object
    slug: string

  ConfigJson = object
    practice: seq[ConfigJsonExercise]

  TrackDir = distinct string

  TrackRepoExercise = object
    dir: string

  TrackExerciseTests* = object
    included*: HashSet[string]
    excluded*: HashSet[string]

  TrackExercise* = object
    slug*: string
    tests*: TrackExerciseTests
    repoExercise: TrackRepoExercise

proc `/`(head: TrackDir, tail: string): string {.borrow.}

func configJsonFile(trackDir: TrackDir): string =
  trackDir / "config.json"

func exercisesDir(trackDir: TrackDir): string =
  trackDir / "exercises"

func practiceExerciseDir(trackDir: TrackDir, exercise: ConfigJsonExercise): string =
  trackDir.exercisesDir / "practice" / exercise.slug

func slug(exercise: TrackRepoExercise): string =
  extractFilename(exercise.dir)

func testsFile(exercise: TrackRepoExercise): string =
  exercise.dir / ".meta" / "tests.toml"

func testsFile*(exercise: TrackExercise): string =
  exercise.repoExercise.testsFile

proc parseConfigJson(filePath: string): ConfigJson =
  let json = json.parseFile(filePath)["exercises"]
  to(json, ConfigJson)

func initTrackRepoExercise(trackDir: TrackDir,
    exercise: ConfigJsonExercise): TrackRepoExercise =
  TrackRepoExercise(dir: trackDir.practiceExerciseDir(exercise))

proc exercises(trackDir: TrackDir): seq[TrackRepoExercise] =
  let config = parseConfigJson(trackDir.configJsonFile)

  for exercise in config.practice:
    result.add(initTrackRepoExercise(trackDir, exercise))

proc initTrackExerciseTests(exercise: TrackRepoExercise): TrackExerciseTests =
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

proc initTrackExercise(exercise: TrackRepoExercise): TrackExercise =
  TrackExercise(
    slug: exercise.slug,
    tests: initTrackExerciseTests(exercise),
  )

proc findTrackExercises(trackDir: TrackDir, conf: Conf): seq[TrackExercise] =
  for repoExercise in trackDir.exercises:
    if conf.action.exercise.len == 0 or conf.action.exercise == repoExercise.slug:
      result.add(initTrackExercise(repoExercise))

proc findTrackExercises*(conf: Conf): seq[TrackExercise] =
  let trackDir = TrackDir(conf.trackDir)
  trackDir.findTrackExercises(conf)
