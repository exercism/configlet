import strformat, sequtils, parsetoml, json, os, tables, options, tracks, probspecs

type
  CanonicalDataCase = object
    uuid: string
    description: string
    cases: seq[CanonicalDataCase]

type
  CanonicalData = object
    exercise: string
    version: string
    cases: seq[CanonicalDataCase]

# {
#   "exercise": "acronym",
#   "version": "1.7.0",
#   "cases": [
#     {
#       "description": "Abbreviate a phrase",
#       "cases": [
#         {
#           "uuid": "cc930a66-93cd-4d55-afd2-da6135f7f502",
#           "description": "basic",
#           "property": "abbreviate",
#           "input": {
#             "phrase": "Portable Network Graphics"
#           },
#           "expected": "PNG"

proc syncExerciseData(exercise: TrackExercise, canonicalData: Option[JsonNode]): void =
  if canonicalData.isNone:
    echo &"Syncing {exercise.slug} (skipped: no canonical data found for this exercise)"
    return

  if not fileExists(exercise.testsTomlFile):
    echo &"Syncing {exercise.slug} (skipped: no tests.toml file found)"
    return

  let tests = parsetoml.parseFile(exercise.testsTomlFile)
  if not tests.hasKey("canonical-tests"):
    echo &"Syncing {exercise.slug} (skipped: no [canonical-tests] section in tests.toml file)"
    return  

proc syncTests*: void =
  echo "Sync"

  let probSpecsRepo = newProbSpecsRepo()
  echo probSpecsRepo.exercises.filterIt(it.slug == "acronym")

  # let exerciseCanonicalData = probSpecsExercisesCanonicalData()

  # for trackExercise in findTrackExercises():
  #   if trackExercise.slug != "acronym":
  #     continue
  #   # TODO: refactor all this
  #   syncExerciseData(trackExercise, exerciseCanonicalData[trackExercise.slug])
