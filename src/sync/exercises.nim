import std/[algorithm, json, options, os, sequtils, sets, strformat, tables]
import pkg/parsetoml
import ".."/cli
import "."/[probspecs, tracks]

type
  ExerciseTestCase* = ref object
    uuid*: string
    description*: string
    json*: JsonNode
    reimplements*: Option[ExerciseTestCase]

  ExerciseTests* = object
    included*: HashSet[string]
    excluded*: HashSet[string]
    missing*: HashSet[string]

  ExerciseStatus* = enum
    exOutOfSync, exInSync, exNoCanonicalData

  Exercise* = object
    slug*: string
    tests*: ExerciseTests
    testCases*: seq[ExerciseTestCase]

func initExerciseTests*(included, excluded, missing: HashSet[string]): ExerciseTests =
  result.included = included
  result.excluded = excluded
  result.missing = missing

proc initExerciseTests(trackExercise: TrackExercise, probSpecsExercise: ProbSpecsExercise): ExerciseTests =
  for testCase in probSpecsExercise.testCases:
    if trackExercise.tests.included.contains(testCase.uuid):
      result.included.incl(testCase.uuid)
    elif trackExercise.tests.excluded.contains(testCase.uuid):
      result.excluded.incl(testCase.uuid)
    else:
      result.missing.incl(testCase.uuid)

proc newExerciseTestCase(testCase: ProbSpecsTestCase): ExerciseTestCase =
  result = new(ExerciseTestCase)
  result.uuid = testCase.uuid
  result.description = testCase.description
  result.json = testCase.json

proc newExerciseTestCases(testCases: seq[ProbSpecsTestCase]): seq[ExerciseTestCase] =
  for testCase in testCases:
    result.add(newExerciseTestCase(testCase))

  let reimplementations = testCases.filterIt(it.isReimplementation).mapIt((it.uuid, it.reimplements)).toTable()
  let testCasesByUuids = result.newTableFrom(proc (testCase: ExerciseTestCase): string = testCase.uuid)

  for testCase in result:
    if testCase.uuid in reimplementations:
      testCase.reimplements = some(testCasesByUuids[reimplementations[testCase.uuid]])

proc initExercise(trackExercise: TrackExercise, probSpecsExercise: ProbSpecsExercise): Exercise =
  result.slug = trackExercise.slug
  result.tests = initExerciseTests(trackExercise, probSpecsExercise)
  result.testCases = newExerciseTestCases(probSpecsExercise.testCases)

proc findExercises*(conf: Conf): seq[Exercise] =
  let probSpecsExercises = findProbSpecsExercises(conf).mapIt((it.slug, it)).toTable

  for trackExercise in findTrackExercises(conf).sortedByIt(it.slug):
    result.add(initExercise(trackExercise, probSpecsExercises.getOrDefault(trackExercise.slug)))

func status*(exercise: Exercise): ExerciseStatus =
  if exercise.testCases.len == 0:
    exNoCanonicalData
  elif exercise.tests.missing.len > 0:
    exOutOfSync
  else:
    exInSync

func hasCanonicalData*(exercise: Exercise): bool =
  exercise.testCases.len > 0

func testsFile(exercise: Exercise, trackDir: string): string =
  trackDir / "exercises" / "practice" / exercise.slug / ".meta" / "tests.toml"

proc toToml(exercise: Exercise, currContents: TomlValueRef): string =
  result.add """
# This is an auto-generated file. Regular comments will be removed when this
# file is regenerated. Regenerating will not touch any manually added keys,
# so comments can be added in a "comment" key.

"""

  for testCase in exercise.testCases:
    if testCase.uuid notin exercise.tests.missing:
      let isIncluded = testCase.uuid in exercise.tests.included

      result.add &"[{testCase.uuid}]\n"
      result.add &"description = \"{testCase.description}\"\n"

      if not isIncluded:
        result.add "include = false\n"

      if currContents.hasKey(testCase.uuid):
        for k, v in currContents[testCase.uuid].getTable():
          if k notin ["description", "include"].toHashSet():
            result.add &"{k} = {v.toTomlString()}\n"

      result.add "\n"

  result.setLen(result.len - 1)

proc parseTomlFile(testsPath: string): TomlValueRef =
  if fileExists(testsPath):
    result = parsetoml.parseFile(testsPath)

proc writeTestsToml*(exercise: Exercise, trackDir: string) =
  let testsPath = testsFile(exercise, trackDir)
  createDir(testsPath.parentDir())

  let currContents = parseTomlFile(testsPath)
  let contents = toToml(exercise, currContents)
  writeFile(testsPath, contents)
