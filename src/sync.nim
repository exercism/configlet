import strformat
import arguments, exercises

proc sync*(args: Arguments): void =
  echo "Syncing exercises..."

  let outOfSyncExercises = findOutOfSyncExercises(args)

  for outOfSyncExercise in outOfSyncExercises:
    echo &"[warn] {outOfSyncExercise.slug} is out of sync ({outofSyncExercise.testCases.missing.len} test cases missing)"

  if outOfSyncExercises.len > 0:
    quit("[warn] some exercises are missing test cases", QuitFailure)
  else:
    quit("All exercises are synced and up-to-date!", QuitSuccess)