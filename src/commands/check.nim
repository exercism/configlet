import options, sequtils, strformat
import ../arguments, ../exercises

proc findExercises(args: Arguments): seq[Exercise] =
  if args.exercise.isNone:
    result = findExercises()
  else:
    result = findExercises().filterIt(it.slug == args.exercise.get)

proc missingTestCases(exercise: Exercise): bool =
  exercise.testCases.missing.len > 0

proc check(exercises: seq[Exercise]): void =
  var missingTestCases = false

  for exercise in exercises:
    if exercise.missingTestCases:
      echo &"[warn] {exercise.slug}"
      missingTestCases = true

  if missingTestCases:
    echo "[warn] some exercises are missing test cases"
  else:
    echo "All exercises are up-to-date!"

proc check*(args: Arguments): void =
  echo "Checking exercises..."

  let exercises = findExercises(args)
  check(exercises)
