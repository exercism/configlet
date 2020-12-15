import std/[algorithm, json, options, os, sequtils, sets, strformat, tables]
import ".."/[cli]
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

proc initExerciseTests*(included, excluded, missing: HashSet[string]): ExerciseTests =
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

proc status*(exercise: Exercise): ExerciseStatus =
  if exercise.testCases.len == 0:
    exNoCanonicalData
  elif exercise.tests.missing.len > 0:
    exOutOfSync
  else:
    exInSync

proc hasCanonicalData*(exercise: Exercise): bool =
  exercise.testCases.len > 0

proc testsFile(exercise: Exercise): string =
  getCurrentDir() / "exercises" / exercise.slug / ".meta" / "tests.toml"

proc toToml(exercise: Exercise): string =
  result.add("[canonical-tests]\n")

  for testCase in exercise.testCases:
    if testCase.uuid in exercise.tests.missing:
      continue

    let isIncluded = testCase.uuid in exercise.tests.included
    result.add(&"\n# {testCase.description}")
    result.add(&"\n\"{testCase.uuid}\" = {isIncluded}\n")

proc writeFile*(exercise: Exercise) =
  createDir(parentDir(exercise.testsFile))

  let file = open(exercise.testsFile, fmWrite)
  write(file, exercise.toToml())
