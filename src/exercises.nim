import algorithm, json, os, sets, sequtils, tables, parsetoml
import arguments, tracks, probspecs

type
  TestCase* = object
    uuid*: string
    description*: string
    json*: JsonNode

  TestCases* = object
    included*: seq[TestCase]
    excluded*: seq[TestCase]
    missing*: seq[TestCase]

  Exercise* = object
    slug*: string
    testsFile*: string
    testCases*: TestCases

proc initTestCase(testCase: ProbSpecsTestCase): TestCase =
  result.uuid = testCase.uuid
  result.description = testCase.description
  result.json = testCase.json

proc initTestCases(trackExercise: TrackExercise, probSpecsExercise: ProbSpecsExercise): TestCases =
  for testCase in probSpecsExercise.testCases:
    if trackExercise.tests.included.contains(testCase.uuid):
      result.included.add(initTestCase(testCase))
    elif trackExercise.tests.excluded.contains(testCase.uuid):
      result.excluded.add(initTestCase(testCase))
    else:
      result.missing.add(initTestCase(testCase))

proc initTestCases(testCases: TestCases, newIncludes: seq[TestCase], newExcludes: seq[TestCase]): TestCases =
  result.included.add(testCases.included & newIncludes)
  result.excluded.add(testCases.excluded & newIncludes)

  for missingTestCase in testCases.missing:
    if missingTestCase notin newIncludes and missingTestCase notin newExcludes:
      result.missing.add(missingTestCase)

proc initExercise(trackExercise: TrackExercise, probSpecsExercise: ProbSpecsExercise): Exercise =
  result.slug = trackExercise.slug
  result.testsFile = trackExercise.testsFile
  result.testCases = initTestCases(trackExercise, probSpecsExercise)

proc initExercise*(exercise: Exercise, newIncludes: seq[TestCase], newExcludes: seq[TestCase]): Exercise =
  result.slug = exercise.slug
  result.testsFile = exercise.testsFile
  result.testCases = initTestCases(exercise.testCases, newIncludes, newExcludes)

proc findExercises(args: Arguments): seq[Exercise] =
  let probSpecsExercises = findProbSpecsExercises(args).mapIt((it.slug, it)).toTable
  
  for trackExercise in findTrackExercises(args).sortedByIt(it.slug):
    if probSpecsExercises.hasKey(trackExercise.slug):
      result.add(initExercise(trackExercise, probSpecsExercises[trackExercise.slug]))

proc findOutOfSyncExercises*(args: Arguments): seq[Exercise] =
  for exercise in findExercises(args):
    if exercise.testCases.missing.len > 0:
      result.add(exercise)

proc toToml*(exerciseTestCases: TestCases): string =
  result.add("[canonical-tests]")
  result.add("")

  # for exerciseTestCase in exerciseTestCases:
  #   result.add(&"# {exerciseTestCase.description}")
    # TODO: write out status

proc writeTestsToFile*(exercise: Exercise): void =
  createDir(parentDir(exercise.testsFile))

  let file = open(exercise.testsFile, fmWrite)
  write(file, exercise.testCases.toToml)
