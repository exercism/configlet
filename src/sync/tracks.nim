import std/[algorithm, json, os, sets]
import pkg/parsetoml
import ".."/cli

type
  TrackDir* {.requiresInit.} = distinct string

  PracticeExerciseSlug* {.requiresInit.} = distinct string

  PracticeExerciseTests* {.requiresInit.} = object
    included*: HashSet[string]
    excluded*: HashSet[string]

  PracticeExercise* {.requiresInit.} = object
    slug*: PracticeExerciseSlug
    tests*: PracticeExerciseTests

proc `/`(head: TrackDir, tail: string): string {.borrow.}
proc `/`(head: string, tail: PracticeExerciseSlug): string {.borrow.}
proc len(x: PracticeExerciseSlug): int {.borrow.}
proc `==`*(x, y: PracticeExerciseSlug): bool {.borrow.}
proc `<`(x, y: PracticeExerciseSlug): bool {.borrow.}
proc `$`*(p: PracticeExerciseSlug): string {.borrow.}

func testsPath*(trackDir: TrackDir, slug: PracticeExerciseSlug): string =
  ## Returns the path to the `tests.toml` file for a given `slug` in a
  ## `trackDir`.
  trackDir / "exercises" / "practice" / slug / ".meta" / "tests.toml"

proc getPracticeExerciseSlugs(trackDir: TrackDir): seq[PracticeExerciseSlug] =
  ## Parses the root `config.json` file in `trackDir` and returns a seq of its
  ## Practice Exercise slugs, in alphabetical order.
  let configFile = trackDir / "config.json"
  if fileExists(configFile):
    let config = json.parseFile(configFile)
    if config.hasKey("exercises"):
      let exercises = config["exercises"]
      if exercises.hasKey("practice"):
        let practiceExercises = exercises["practice"]
        result = newSeqOfCap[PracticeExerciseSlug](practiceExercises.len)

        for exercise in practiceExercises:
          if exercise.hasKey("slug"):
            if exercise["slug"].kind == JString:
              let slug = exercise["slug"].getStr()
              result.add PracticeExerciseSlug(slug)
    else:
      stderr.writeLine "Error: file does not have an `exercises` key:\n" &
                       configFile
      quit(1)
  else:
    stderr.writeLine "Error: file does not exist:\n" & configFile
    quit(1)

  sort result

proc initPracticeExerciseTests(testsPath: string): PracticeExerciseTests =
  ## Parses the `tests.toml` file at `testsPath` and returns HashSets of the
  ## included and excluded test case UUIDs.
  result = PracticeExerciseTests(
    included: initHashSet[string](),
    excluded: initHashSet[string](),
  )
  if fileExists(testsPath):
    let tests = parsetoml.parseFile(testsPath)

    for uuid, val in tests.getTable():
      if val.hasKey("include"):
        if val["include"].kind == Bool:
          let isIncluded = val["include"].getBool()
          if isIncluded:
            result.included.incl uuid
          else:
            result.excluded.incl uuid
        else:
          let msg = "Error: the value of an `include` key is `" &
                    val["include"].toTomlString() & "`, but it must be a " &
                    "bool:\n" & testsPath
          stderr.writeLine(msg)
      else:
        result.included.incl uuid

proc findPracticeExercises*(conf: Conf): seq[PracticeExercise] =
  let trackDir = TrackDir(conf.trackDir)
  let userExercise = PracticeExerciseSlug(conf.action.exercise)

  let practiceExerciseSlugs = getPracticeExerciseSlugs(trackDir)
  result = newSeqOfCap[PracticeExercise](practiceExerciseSlugs.len)

  for slug in practiceExerciseSlugs:
    if userExercise.len == 0 or userExercise == slug:
      let testsPath = testsPath(trackDir, slug)
      let p = PracticeExercise(
        slug: slug,
        tests: initPracticeExerciseTests(testsPath),
      )
      result.add p
