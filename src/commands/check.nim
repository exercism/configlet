import sequtils, strformat
import ../exercises

proc missingTestCases(exercise: Exercise): bool =
  exercise.testCases.missing.len > 0

proc printExerciseStatuses(exercises: seq[Exercise]): void =
  for exercise in exercises:
    if exercise.missingTestCases:
      echo &"[warn] {exercise.slug}"

proc printOverallStatus(exercises: seq[Exercise]): void =
  if exercises.anyIt(it.missingTestCases):
    echo "[warn] some exercises are missing test cases"
  else:
    echo "All exercises are up-to-date!"

proc check*: void =
  echo "Checking exercises..."

  let exercises = findExercises()
  printExerciseStatuses(exercises)
  printOverallStatus(exercises)
