import std/[json, os, sets]
import pkg/parsetoml
import ".."/cli

type
  TrackDir* {.requiresInit.} = distinct string

  PracticeExercisePath {.requiresInit.} = distinct string

  PracticeExerciseTests* = object
    included*: HashSet[string]
    excluded*: HashSet[string]

  PracticeExercise* = object
    slug*: string
    tests*: PracticeExerciseTests

proc `/`(head: TrackDir, tail: string): string {.borrow.}
proc `/`(head: PracticeExercisePath, tail: string): string {.borrow.}
proc extractFilename(exercisePath: PracticeExercisePath): string {.borrow.}

func slug(exercisePath: PracticeExercisePath): string =
  extractFilename(exercisePath)

func testsFile*(exercisePath: PracticeExercisePath): string =
  exercisePath / ".meta" / "tests.toml"

func initPracticeExercisePath*(trackDir: TrackDir,
                               slug: string): PracticeExercisePath =
  PracticeExercisePath(trackDir / "exercises" / "practice" / slug)

proc getPracticeExercisePaths(trackDir: TrackDir): seq[PracticeExercisePath] =
  let configFile = trackDir / "config.json"
  if fileExists(configFile):
    let config = json.parseFile(configFile)
    if config.hasKey("exercises"):
      let exercises = config["exercises"]
      if exercises.hasKey("practice"):
        let practiceExercises = exercises["practice"]
        result = newSeqOfCap[PracticeExercisePath](practiceExercises.len)

        for exercise in practiceExercises:
          if exercise.hasKey("slug"):
            if exercise["slug"].kind == JString:
              let slug = exercise["slug"].getStr()
              result.add initPracticeExercisePath(trackDir, slug)
    else:
      stderr.writeLine "Error: file does not have an `exercises` key:\n" &
                       configFile
      quit(1)
  else:
    stderr.writeLine "Error: file does not exist:\n" & configFile
    quit(1)

proc initPracticeExerciseTests(exercisePath: PracticeExercisePath): PracticeExerciseTests =
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

proc initPracticeExercise(exercisePath: PracticeExercisePath): PracticeExercise =
  PracticeExercise(
    slug: slug(exercisePath),
    tests: initPracticeExerciseTests(exercisePath),
  )

proc findPracticeExercises*(conf: Conf): seq[PracticeExercise] =
  let trackDir = TrackDir(conf.trackDir)
  let userExercise = conf.action.exercise

  let practiceExercisePaths = getPracticeExercisePaths(trackDir)
  result = newSeqOfCap[PracticeExercise](practiceExercisePaths.len)

  for practiceExercisePath in practiceExercisePaths:
    if userExercise.len == 0 or userExercise == slug(practiceExercisePath):
      result.add initPracticeExercise(practiceExercisePath)
