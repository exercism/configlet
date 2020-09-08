import strformat
import sequtils
import parsetoml
import json
import os
import tracks
import probspecsrepo

proc syncExerciseData(exercise: TrackExercise): void =
  if not fileExists(exercise.testsTomlFile):
    echo &"Syncing {exercise.slug} (skipped)"
    return
  
  echo &"Syncing {exercise.slug}"
  let tests = parsetoml.parseFile(exercise.testsTomlFile)
# exercise.
  # json.parseFile(exercise.)
  echo tests["canonical-tests"].toJson.pretty()
  for k, v in tests["canonical-tests"].getTable().pairs:
    echo &"Found elem: {k},{v}" 

proc syncExercisesData*: void =
  for probSpecExercise in findProbSpecExercises():
    echo probSpecExercise

  # for trackExercise in findTrackExercises():
  #     syncExerciseData(trackExercise)
