import std/[json, os, sets]
import pkg/parsetoml
import ".."/cli

type
  ConfigJsonSlug = distinct string

  TrackDir = distinct string

  ExercisePath = distinct string

  TrackExerciseTests* = object
    included*: HashSet[string]
    excluded*: HashSet[string]

  TrackExercise* = object
    slug*: string
    tests*: TrackExerciseTests
    exercisePath: ExercisePath

proc `/`(head: TrackDir, tail: string): string {.borrow.}
proc `/`(head: ExercisePath, tail: string): string {.borrow.}
proc `/`(head: string, tail: ConfigJsonSlug): string {.borrow.}
proc extractFilename(exercise: ExercisePath): string {.borrow.}

func slug(exercisePath: ExercisePath): string =
  extractFilename(exercisePath)

func testsFile(exercisePath: ExercisePath): string =
  exercisePath / ".meta" / "tests.toml"

func testsFile*(exercise: TrackExercise): string =
  exercise.exercisePath.testsFile()

func initExercisePath(trackDir: TrackDir, slug: ConfigJsonSlug): ExercisePath =
  ExercisePath(trackDir / "exercises" / "practice" / slug)

proc exercises(trackDir: TrackDir): seq[ExercisePath] =
  let config = json.parseFile(trackDir / "config.json")["exercises"]

  if config.hasKey("practice"):
    let practiceExercises = config["practice"]
    result = newSeqOfCap[ExercisePath](practiceExercises.len)

    for exercise in practiceExercises:
      if exercise.hasKey("slug"):
        if exercise["slug"].kind == JString:
          let configJsonSlug = ConfigJsonSlug(exercise["slug"].getStr())
          result.add initExercisePath(trackDir, configJsonSlug)

proc initTrackExerciseTests(exercisePath: ExercisePath): TrackExerciseTests =
  let testsFile = testsFile(exercisePath)
  if fileExists(testsFile):
    let tests = parsetoml.parseFile(testsFile)

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
                    exercisePath.testsFile()
          stderr.writeLine(msg)
      else:
        result.included.incl(uuid)

proc initTrackExercise(exercisePath: ExercisePath): TrackExercise =
  TrackExercise(
    slug: slug(exercisePath),
    tests: initTrackExerciseTests(exercisePath),
  )

proc findTrackExercises(trackDir: TrackDir, userExercise: string): seq[TrackExercise] =
  let exercisePaths = exercises(trackDir)
  result = newSeqOfCap[TrackExercise](exercisePaths.len)

  for exercisePath in exercisePaths:
    if userExercise.len == 0 or userExercise == slug(exercisePath):
      result.add initTrackExercise(exercisePath)

proc findTrackExercises*(conf: Conf): seq[TrackExercise] =
  let trackDir = TrackDir(conf.trackDir)
  result = findTrackExercises(trackDir, conf.action.exercise)
