import strformat
import ../arguments, ../exercises

proc update(exercises: seq[Exercise]): void =
  discard

proc update*(args: Arguments): void =
  echo "Updating exercises..."

  let exercises = findExercises(args)
  update(exercises)

  # for exercise in findExercises():
  #   echo &"[{exercise.slug}]"
  #   echo &"  total:    {exercise.testCases.len}"
  #   echo &"  included: {exercise.testCases.included.len}"
  #   echo &"  excluded: {exercise.testCases.excluded.len}"
  #   echo &"  missing:  {exercise.testCases.missing.len}"
  #   echo ""
