import strformat
import ../arguments, ../exercises

proc update(exercises: seq[Exercise], args: Arguments): void =
  for exercise in exercises:
    if exercise.testCases.missing.len > 0:
      echo &"[warn] {exercise.slug}: {exercise.testCases.missing.len} test cases missing"

  discard

proc update*(args: Arguments): void =
  echo "Updating exercises..."

  let exercises = findExercises(args)
  update(exercises, args)

  # for exercise in findExercises():
  #   echo &"[{exercise.slug}]"
  #   echo &"  total:    {exercise.testCases.len}"
  #   echo &"  included: {exercise.testCases.included.len}"
  #   echo &"  excluded: {exercise.testCases.excluded.len}"
  #   echo &"  missing:  {exercise.testCases.missing.len}"
  #   echo ""
