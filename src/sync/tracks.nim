import std/[json, os, sets]
import pkg/parsetoml
import ".."/cli

type
  TrackDir {.requiresInit.} = distinct string

  PracticeExercisePath {.requiresInit.} = distinct string

  TrackExerciseTests* = object
    included*: HashSet[string]
    excluded*: HashSet[string]

  TrackExercise* = object
    slug*: string
    tests*: TrackExerciseTests

proc `/`(head: TrackDir, tail: string): string {.borrow.}
proc `/`(head: PracticeExercisePath, tail: string): string {.borrow.}
proc extractFilename(exercisePath: PracticeExercisePath): string {.borrow.}

func slug(exercisePath: PracticeExercisePath): string =
  extractFilename(exercisePath)

func testsFile(exercisePath: PracticeExercisePath): string =
  exercisePath / ".meta" / "tests.toml"

func testsFile*(exercise: TrackExercise): string =
  PracticeExercisePath("").testsFile()

proc getPracticeExercisePaths(trackDir: TrackDir): seq[PracticeExercisePath] =
  let config = json.parseFile(trackDir / "config.json")["exercises"]

  if config.hasKey("practice"):
    let practiceExercises = config["practice"]
    result = newSeqOfCap[PracticeExercisePath](practiceExercises.len)

    for exercise in practiceExercises:
      if exercise.hasKey("slug"):
        if exercise["slug"].kind == JString:
          let slug = exercise["slug"].getStr()
          let path = trackDir / "exercises" / "practice" / slug
          result.add PracticeExercisePath(path)

proc initTrackExerciseTests(exercisePath: PracticeExercisePath): TrackExerciseTests =
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
                    val["include"].toTomlString() & "`, but it must be a " &
                    "bool:\n" & exercisePath.testsFile()
          stderr.writeLine(msg)
      else:
        result.included.incl(uuid)

proc initTrackExercise(exercisePath: PracticeExercisePath): TrackExercise =
  TrackExercise(
    slug: slug(exercisePath),
    tests: initTrackExerciseTests(exercisePath),
  )

proc findTrackExercises(trackDir: TrackDir,
                        userExercise: string): seq[TrackExercise] =
  let practiceExercisePaths = getPracticeExercisePaths(trackDir)
  result = newSeqOfCap[TrackExercise](practiceExercisePaths.len)

  for practiceExercisePath in practiceExercisePaths:
    if userExercise.len == 0 or userExercise == slug(practiceExercisePath):
      result.add initTrackExercise(practiceExercisePath)

proc findTrackExercises*(conf: Conf): seq[TrackExercise] =
  let trackDir = TrackDir(conf.trackDir)
  result = findTrackExercises(trackDir, conf.action.exercise)
