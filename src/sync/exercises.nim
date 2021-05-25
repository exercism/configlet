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

  ExerciseTests* {.requiresInit.} = object
    included*: HashSet[string]
    excluded*: HashSet[string]
    missing*: HashSet[string]

  ExerciseStatus* = enum
    exOutOfSync, exInSync, exNoCanonicalData

  Exercise* {.requiresInit.} = object
    slug*: PracticeExerciseSlug
    tests*: ExerciseTests
    testCases*: seq[ExerciseTestCase]

func initExerciseTests*(included, excluded, missing: HashSet[string]): ExerciseTests =
  ExerciseTests(
    included: included,
    excluded: excluded,
    missing: missing,
  )

func initExerciseTests(practiceExerciseTests: PracticeExerciseTests,
                       probSpecsTestCases: seq[ProbSpecsTestCase]): ExerciseTests =
  result = ExerciseTests(
    included: initHashSet[string](),
    excluded: initHashSet[string](),
    missing: initHashSet[string](),
  )
  for testCase in probSpecsTestCases:
    let uuid = uuid(testCase)
    if uuid in practiceExerciseTests.included:
      result.included.incl uuid
    elif uuid in practiceExerciseTests.excluded:
      result.excluded.incl uuid
    else:
      result.missing.incl uuid

func newExerciseTestCase(testCase: ProbSpecsTestCase): ExerciseTestCase =
  ExerciseTestCase(
    uuid: uuid(testCase),
    description: description(testCase),
    json: testCase,
  )

func getReimplementations(testCases: seq[ProbSpecsTestCase]): Table[string, string] =
  for testCase in testCases:
    if testCase.isReimplementation():
      result[testCase.uuid()] = testCase.reimplements()

func uuidToTestCase(testCases: seq[ExerciseTestCase]): Table[string, ExerciseTestCase] =
  for testCase in testCases:
    result[testCase.uuid] = testCase

func initExerciseTestCases(testCases: seq[ProbSpecsTestCase]): seq[ExerciseTestCase] =
  result = newSeq[ExerciseTestCase](testCases.len)
  for i, testCase in testCases:
    result[i] = newExerciseTestCase(testCase)

  let reimplementations = getReimplementations(testCases)
  let testCasesByUuids = uuidToTestCase(result)

  for testCase in result:
    let uuid = testCase.uuid
    if uuid in reimplementations:
      let uuidOfReimplementation = reimplementations[uuid]
      testCase.reimplements = some(testCasesByUuids[uuidOfReimplementation])

iterator findExercises*(conf: Conf): Exercise {.inline.} =
  let probSpecsExercises = findProbSpecsExercises(conf)

  for practiceExercise in findPracticeExercises(conf):
    let testCases = probSpecsExercises.getOrDefault(practiceExercise.slug.string)
    yield Exercise(
      slug: practiceExercise.slug,
      tests: initExerciseTests(practiceExercise.tests, testCases),
      testCases: initExerciseTestCases(testCases),
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
  ## preserves every property apart from `description` and `include = true`.
  result = """
# This is an auto-generated file. Regular comments will be removed when this
# file is regenerated. Regenerating will not touch any manually added keys,
# so comments can be added in a "comment" key.

"""

  for testCase in exercise.testCases:
    let uuid = testCase.uuid
    if uuid notin exercise.tests.missing:
      result.add &"[{uuid}]\n"
      # Always use the latest `description` value
      result.add &"description = \"{testCase.description}\"\n"

      # Omit `include = true`
      if uuid notin exercise.tests.included:
        result.add "include = false\n"

      if fileExists(testsPath):
        let currContents = parsetoml.parseFile(testsPath)
        if currContents.hasKey(uuid):
          # Preserve custom properties
          for k, v in currContents[uuid].getTable():
            if k notin ["description", "include"].toHashSet():
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
