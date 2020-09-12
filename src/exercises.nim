import sequtils, tables, tracks, probspecs, sets, json

type
  TestCaseStatus* = enum
    enabled, disabled, unknown

  TestCase* = object
    uuid*: string
    description*: string
    json*: JsonNode
    status*: TestCaseStatus

  Exercise* = object
    slug*: string
    testCases*: seq[TestCase]

proc testCaseStatus(trackExercise: TrackExercise, testCase: ProbSpecsTestCase): TestCaseStatus =
  if trackExercise.tests.included.contains(testCase.uuid):
    enabled
  elif trackExercise.tests.excluded.contains(testCase.uuid):
    disabled
  else:
    unknown

proc newTestCase(trackExercise: TrackExercise, testCase: ProbSpecsTestCase): TestCase =
  TestCase(
    uuid: testCase.uuid,
    description: testCase.description,
    json: testCase.json,
    status: testCaseStatus(trackExercise, testCase)
  )

proc newTestCases(trackExercise: TrackExercise, probSpecsExercise: ProbSpecsExercise): seq[TestCase] =
  probSpecsExercise.testCases.mapIt(newTestCase(trackExercise, it))

proc newExercise(trackExercise: TrackExercise, probSpecsExercise: ProbSpecsExercise): Exercise =
  Exercise(slug: trackExercise.slug, testCases: newTestCases(trackExercise, probSpecsExercise))

proc findExercises*: seq[Exercise] =
  let probSpecsExercises = findProbSpecsExercises().mapIt((it.slug, it)).toTable
  
  for trackExercise in findTrackExercises():
    if probSpecsExercises.hasKey(trackExercise.slug):
      result.add(newExercise(trackExercise, probSpecsExercises[trackExercise.slug]))
