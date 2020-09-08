import strformat
import sequtils
import parsetoml
import json
import os
import exercises

proc syncExerciseData(exercise: Exercise): void =
  if not fileExists(exercise.testsTomlFile):
    # echo &"Syncing {exercise.slug} (skipped)"
    return
  
  # echo &"Syncing {exercise.slug}"
  let tests = parsetoml.parseFile(exercise.testsTomlFile)
  echo tests["canonical-tests"].toJson.pretty()
  for k, v in tests["canonical-tests"].getTable().pairs:
    echo &"Found elem: {k},{v}" 

proc syncExercisesData*: void =
  for exercise in findExercises():
      syncExerciseData(exercise)
