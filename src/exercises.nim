import std/[algorithm, json, options, os, sets, sequtils, strformat, tables]
import arguments, tracks, probspecs

type
  ExerciseTestCase* = object
    uuid*: string
    description*: string
    json*: JsonNode
    reimplements*: Option[JsonNode]

  ExerciseTests* = object
    included*: HashSet[string]
    excluded*: HashSet[string]
    missing*: HashSet[string]

  ExerciseStatus* {.pure.} = enum
    outOfSync, inSync, noCanonicalData

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

proc initExerciseTestCase(testCase: ProbSpecsTestCase, reimplements: Option[JsonNode]): ExerciseTestCase =
  result.uuid = testCase.uuid
  result.description = testCase.description
  result.json = testCase.json
  result.reimplements = reimplements

proc initExerciseTestCases(testCases: seq[ProbSpecsTestCase]): seq[ExerciseTestCase] =  
  let uuidToJson = testCases.mapIt((it.uuid, it.json)).toTable()
  
  for testCase in testCases:
    if testCase.reimplementation:
      result.add(initExerciseTestCase(testCase, some(uuidToJson[testCase.reimplements])))
    else:
      result.add(initExerciseTestCase(testCase, none(JsonNode)))

proc initExercise(trackExercise: TrackExercise, probSpecsExercise: ProbSpecsExercise): Exercise =
  result.slug = trackExercise.slug
  result.tests = initExerciseTests(trackExercise, probSpecsExercise)
  result.testCases = initExerciseTestCases(probSpecsExercise.testCases)

proc findExercises*(args: Arguments): seq[Exercise] =
  let probSpecsExercises = findProbSpecsExercises(args).mapIt((it.slug, it)).toTable
  
  for trackExercise in findTrackExercises(args).sortedByIt(it.slug):
    result.add(initExercise(trackExercise, probSpecsExercises.getOrDefault(trackExercise.slug)))

proc status*(exercise: Exercise): ExerciseStatus = 
  if exercise.testCases.len == 0:
    ExerciseStatus.noCanonicalData
  elif exercise.tests.missing.len > 0:
    ExerciseStatus.outOfSync
  else:
    ExerciseStatus.inSync

proc hasCanonicalData*(exercise: Exercise): bool =
  exercise.testCases.len > 0

proc testsFile(exercise: Exercise): string =
  getCurrentDir() / "exercises" / exercise.slug / ".meta" / "tests.toml"

proc toToml(exercise: Exercise): string =
  result.add("[canonical-tests]\n")

  for testCase in exercise.testCases:
    if testCase.uuid in exercise.tests.missing:
      continue
    
    let included = testCase.uuid in exercise.tests.included
    result.add(&"\n# {testCase.description}")
    result.add(&"\n\"{testCase.uuid}\" = {included}\n")

proc writeFile*(exercise: Exercise): void =
  createDir(parentDir(exercise.testsFile))

  let file = open(exercise.testsFile, fmWrite)
  write(file, exercise.toToml())
