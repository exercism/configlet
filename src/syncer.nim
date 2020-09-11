import strformat, sequtils, parsetoml, json, os, tables, options, tracks, probspecsrepo

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
    
  # let canonicalTests = toSeq(tests["canonical-tests"].getTable().pairs)
  #   .mapIt((it[0], it[1].getBool()))
  #   .toTable

  # for canonicalCase in canonicalData.get["cases"].getElems():
  #   # if canonicalCase.hasKey("uuid"):
  #   #   if canonicalCase["uuid"] == "2009a269-4cc9-4e30-8156-f5331b6269f5":
  #   #     canonicalCase.delete()
      
  #   if canonicalCase.hasKey("cases"):
  #     for subCase in canonicalCase["cases"].getElems():
  #       echo subCase
  #       echo ""
    

  # echo canonicalData.get.pretty

proc syncTests*: void =
  echo "Sync"
  # let exerciseCanonicalData = probSpecsExercisesCanonicalData()

  # for trackExercise in findTrackExercises():
  #   if trackExercise.slug != "acronym":
  #     continue
  #   # TODO: refactor all this
  #   syncExerciseData(trackExercise, exerciseCanonicalData[trackExercise.slug])
