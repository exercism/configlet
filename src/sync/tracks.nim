import std/[algorithm, json, os, sets, strformat, strutils]
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
proc len(x: PracticeExerciseSlug): int {.borrow.}
proc `==`*(x, y: PracticeExerciseSlug): bool {.borrow.}
proc `<`(x, y: PracticeExerciseSlug): bool {.borrow.}
proc `$`*(p: PracticeExerciseSlug): string {.borrow.}

func testsPath*(trackDir: TrackDir, slug: PracticeExerciseSlug): string =
  ## Returns the path to the `tests.toml` file for a given `slug` in a
  ## `trackDir`.
  joinPath(trackDir.string, "exercises", "practice", slug.string, ".meta",
           "tests.toml")

proc getPracticeExerciseSlugs(trackDir: TrackDir,
                              withDeprecated: bool): seq[PracticeExerciseSlug] =
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
          if exercise.hasKey("slug") and exercise["slug"].kind == JString:
            if withDeprecated or not exercise.hasKey("status") or
                exercise["status"].kind != JString or
                exercise["status"].getStr() != "deprecated":
              let slug = exercise["slug"].getStr()
              result.add PracticeExerciseSlug(slug)
    else:
      stderr.writeLine "Error: file does not have an `exercises` key:\n" &
                       configFile
      quit(QuitFailure)
  else:
    stderr.writeLine "Error: file does not exist:\n" & configFile
    quit(QuitFailure)

  sort result

func init(T: typedesc[PracticeExerciseTests]): T =
  T(
    included: initHashSet[string](),
    excluded: initHashSet[string](),
  )

proc init(T: typedesc[PracticeExerciseTests], testsPath: string): T =
  ## Parses the `tests.toml` file at `testsPath` and returns HashSets of the
  ## included and excluded test case UUIDs.
  result = PracticeExerciseTests.init()
  if fileExists(testsPath):
    let tests =
      try:
        parsetoml.parseFile(testsPath)
      except TomlError:
        stderr.writeLine fmt"""

          Error: A 'tests.toml' file contains invalid TOML:
          {getCurrentExceptionMsg()}

          The expected 'tests.toml' format is documented in
          https://exercism.org/docs/building/configlet/sync#h-tests""".unindent()
        quit(QuitFailure)
      except CatchableError:
        stderr.writeLine "Error: " & getCurrentExceptionMsg()
        quit(QuitFailure)

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

iterator findPracticeExercises*(conf: Conf): PracticeExercise {.inline.} =
  let trackDir = TrackDir(conf.trackDir)
  let userExercise = PracticeExerciseSlug(conf.action.exercise)

  let practiceExerciseSlugs = getPracticeExerciseSlugs(trackDir,
                                                       withDeprecated = false)

  for slug in practiceExerciseSlugs:
    if userExercise.len == 0 or userExercise == slug:
      # Parse `tests.toml` only when necessary
      if skTests in conf.action.scope:
        let testsPath = testsPath(trackDir, slug)
        yield PracticeExercise(
          slug: slug,
          tests: PracticeExerciseTests.init(testsPath),
        )
      else:
        yield PracticeExercise(
          slug: slug,
          tests: PracticeExerciseTests.init(),
        )
