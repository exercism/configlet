import sequtils, tables, tracks, probspecs, json

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

proc newTests(trackExercise: TrackExercise): OrderedTable[string, bool] =
  trackExercise.tests.mapIt((it.uuid, it.enabled)).toOrderedTable

proc newTestCase(testCase: ProbSpecsTestCase): TestCase =
  TestCase(uuid: testCase.uuid, description: testCase.description, json: testCase.json)

proc newTestCases(trackExercise: TrackExercise, probSpecsExercise: ProbSpecsExercise): Table[string, TestCase] =
  probSpecsExercise.testCases.map(newTestCase).mapIt((it.uuid, it)).toTable

proc newExercise(trackExercise: TrackExercise, probSpecsExercise: ProbSpecsExercise): Exercise =
  Exercise(slug: trackExercise.slug, tests: newTests(trackExercise), testCases: newTestCases(probSpecsExercise))

proc findExercises*: seq[Exercise] =
  let probSpecsExercises = findProbSpecsExercises().mapIt((it.slug, it)).toTable
  
  for trackExercise in findTrackExercises():
    if probSpecsExercises.hasKey(trackExercise.slug):
      result.add(newExercise(trackExercise, probSpecsExercises[trackExercise.slug]))
