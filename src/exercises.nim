import algorithm, sequtils, tables, sets, json
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

proc initExercise(trackExercise: TrackExercise, probSpecsExercise: ProbSpecsExercise): Exercise =
  result.slug = trackExercise.slug
  result.testCases = initTestCases(trackExercise, probSpecsExercise)

proc findExercises(args: Arguments): seq[Exercise] =
  let probSpecsExercises = findProbSpecsExercises(args).mapIt((it.slug, it)).toTable
  
  for trackExercise in findTrackExercises(args).sortedByIt(it.slug):
    if probSpecsExercises.hasKey(trackExercise.slug):
      result.add(initExercise(trackExercise, probSpecsExercises[trackExercise.slug]))

proc findOutOfSyncExercises*(args: Arguments): seq[Exercise] =
  for exercise in findExercises(args):
    if exercise.testCases.missing.len > 0:
      result.add(exercise)