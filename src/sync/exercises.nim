import std/[options, os, sets, strformat, strutils, tables]
import pkg/parsetoml
import ".."/cli
import "."/[probspecs, tracks]
export tracks.`$`, probspecs.pretty

type
  ExerciseTestCase* {.requiresInit.} = ref object
    uuid*: string
    description*: string
    json*: ProbSpecsTestCase
    reimplements*: Option[ExerciseTestCase]

  ExerciseTestCases = seq[ExerciseTestCase]

  ExerciseTests* {.requiresInit.} = object
    included*: HashSet[string]
    excluded*: HashSet[string]
    missing*: HashSet[string]

  ExerciseStatus* = enum
    exOutOfSync, exInSync, exNoCanonicalData

  Exercise* {.requiresInit.} = object
    slug*: PracticeExerciseSlug
    tests*: ExerciseTests
    testCases*: ExerciseTestCases

func init(T: typedesc[ExerciseTests]): T =
  T(
    included: initHashSet[string](),
    excluded: initHashSet[string](),
    missing: initHashSet[string](),
  )

proc init(T: typedesc[ExerciseTests],
          practiceExerciseTests: PracticeExerciseTests,
          probSpecsTestCases: ProbSpecsTestCases): T =
  result = ExerciseTests.init()
  for testCase in probSpecsTestCases:
    let uuid = uuid(testCase)
    if uuid in practiceExerciseTests.included:
      result.included.incl uuid
    elif uuid in practiceExerciseTests.excluded:
      result.excluded.incl uuid
    else:
      result.missing.incl uuid

proc new(T: typedesc[ExerciseTestCase], testCase: ProbSpecsTestCase): T =
  T(
    uuid: uuid(testCase),
    description: description(testCase),
    json: testCase,
    reimplements: Option[ExerciseTestCase](), # `none` produces a ProveInit warning
  )

proc getReimplementations(testCases: ProbSpecsTestCases): Table[string, string] =
  for testCase in testCases:
    if testCase.isReimplementation():
      result[testCase.uuid()] = testCase.reimplements()

func uuidToTestCase(testCases: ExerciseTestCases): Table[string, ExerciseTestCase] =
  for testCase in testCases:
    result[testCase.uuid] = testCase

proc init(T: typedesc[ExerciseTestCases], testCases: ProbSpecsTestCases): T =
  result = newSeq[ExerciseTestCase](testCases.len)
  var hasReimplementation = false

  for i, testCase in testCases:
    result[i] = ExerciseTestCase.new(testCase)
    if testCase.isReimplementation():
      hasReimplementation = true

  if hasReimplementation:
    let reimplementations = getReimplementations(testCases)
    let testCasesByUuids = uuidToTestCase(result)

    for testCase in result:
      let uuid = testCase.uuid
      if uuid in reimplementations:
        let uuidOfReimplementation = reimplementations[uuid]
        testCase.reimplements = some(testCasesByUuids[uuidOfReimplementation])

iterator findExercises*(conf: Conf, probSpecsDir: ProbSpecsDir): Exercise {.inline.} =
  for practiceExercise in findPracticeExercises(conf):
    # Parse `canonical-data.json` only when necessary
    if skTests in conf.action.scope:
      let testCases = getCanonicalTests(probSpecsDir, practiceExercise.slug.string)
      yield Exercise(
        slug: practiceExercise.slug,
        tests: ExerciseTests.init(practiceExercise.tests, testCases),
        testCases: ExerciseTestCases.init(testCases),
      )
    else:
      yield Exercise(
        slug: practiceExercise.slug,
        tests: ExerciseTests.init(),
        testCases: @[],
      )

func status*(exercise: Exercise): ExerciseStatus =
  if exercise.testCases.len == 0:
    exNoCanonicalData
  elif exercise.tests.missing.len > 0:
    exOutOfSync
  else:
    exInSync

func prettyTomlString(s: string): string =
  ## Returns `s` as a TOML string. This tries to handle multi-line strings,
  ## which `parsetoml.toTomlString` doesn't handle properly.
  if s.contains("\n"):
    &"\"\"\"\n{s}\"\"\""
  else:
    &"\"{s}\""

proc prettyTomlString(a: openArray[TomlValueRef]): string =
  ## Returns the array `a` as a prettified TOML string.
  if a.len > 0:
    result = "[\n"
    for item in a:
      result.add &"  {item.toTomlString()},\n" # Keep the final trailing comma.
    result.add "]"
  else:
    result = "[]"

proc toToml(exercise: Exercise, testsPath: string): string =
  ## Returns the new contents of a `tests.toml` file that corresponds to an
  ## `exercise`. This proc reads the previous contents at `testsPath` and
  ## generates the up-to-date `description` and `reimplements` key/value pairs,
  ## removes any `include = true`, and preserves any other key/value pair.
  result = """
# This is an auto-generated file.
#
# Regenerating this file via `configlet sync` will:
# - Recreate every `description` key/value pair
# - Recreate every `reimplements` key/value pair, where they exist in problem-specifications
# - Remove any `include = true` key/value pair (an omitted `include` key implies inclusion)
# - Preserve any other key/value pair
#
# As user-added comments (using the # character) will be removed when this file
# is regenerated, comments can be added via a `comment` key.

"""

  let currContents =
    if fileExists(testsPath):
      parsetoml.parseFile(testsPath)
    else:
      nil

  for testCase in exercise.testCases:
    let uuid = testCase.uuid
    if uuid notin exercise.tests.missing:
      result.add &"[{uuid}]\n"
      # Always use the latest `description` value
      result.add &"description = \"{testCase.description}\"\n"

      # Omit `include = true`
      if uuid in exercise.tests.excluded:
        result.add "include = false\n"

      # Always add the `reimplements` key/value pair, if present
      if testCase.reimplements.isSome():
        result.add &"reimplements = \"{testCase.reimplements.get().uuid}\"\n"

      if not currContents.isNil():
        if currContents.hasKey(uuid):
          # Preserve any other key/value pair
          for k, v in currContents[uuid].getTable():
            if k notin ["description", "include", "reimplements"].toHashSet():
              let vTomlString =
                if v.kind == String:
                  prettyTomlString(v.stringVal)
                elif v.kind == Array:
                  prettyTomlString(v.arrayVal)
                else:
                  toTomlString(v)
              result.add &"{k} = {vTomlString}\n"

      result.add "\n"

  result.setLen(result.len - 1)

proc writeTestsToml*(exercise: Exercise, trackDir: string) =
  let testsPath = testsPath(TrackDir(trackDir), exercise.slug)
  createDir(testsPath.parentDir())

  let contents = toToml(exercise, testsPath)
  writeFile(testsPath, contents)
