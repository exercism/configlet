import sequtils, tables, tracks, probspecs, algorithm, json

type
  TestCase* = object
    uuid*: string
    description*: string
    json*: string

  Exercise = object
    slug*: string
    tests*: OrderedTable[string, bool]
    testCases*: Table[string, TestCase]

proc newTests(trackExercise: TrackExercise): OrderedTable[string, bool] =
  if trackExercise.hasTests:
    trackExercise.tests.mapIt((it.uuid, it.enabled)).toOrderedTable
  else:
    initOrderedTable[string, bool]()

proc newTestCase(testCase: ProbSpecsTestCase): TestCase =
  TestCase(uuid: testCase.uuid, description: testCase.description, json: testCase.json.pretty())

proc newTestCases(probSpecsExercise: ProbSpecsExercise): Table[string, TestCase] =
  probSpecsExercise.testCases.map(newTestCase).mapIt((it.uuid, it)).toTable

proc newExercise(trackExercise: TrackExercise, probSpecsExercise: ProbSpecsExercise): Exercise =
  Exercise(slug: trackExercise.slug, tests: newTests(trackExercise), testCases: newTestCases(probSpecsExercise))

proc findExercises*: seq[Exercise] =
  let probSpecsExercisesBySlug = findProbSpecsExercises().mapIt((it.slug, it)).toOrderedTable
  let trackExercises = findTrackExercises().sortedByIt(it.slug)

  for trackExercise in trackExercises:
    if not probSpecsExercisesBySlug.hasKey(trackExercise.slug):
      continue

    let probSpecsExercise = probSpecsExercisesBySlug[trackExercise.slug]
    if not probSpecsExercise.hasCanonicalData:
      continue

    result.add(newExercise(trackExercise, probSpecsExercise))
