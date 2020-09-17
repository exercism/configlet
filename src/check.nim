import strformat
import arguments, exercises

proc check*(args: Arguments): void =
  echo "Checking exercises..."

  let outOfSyncExercises = findOutOfSyncExercises(args)

  for outOfSyncExercise in outOfSyncExercises:
    echo &"[warn] {outOfSyncExercise.slug} is missing {outofSyncExercise.testCases.missing.len} test cases"

  if outOfSyncExercises.len > 0:
    quit("[warn] some exercises are missing test cases", QuitFailure)
  else:
    quit("All exercises are up-to-date!", QuitSuccess)
