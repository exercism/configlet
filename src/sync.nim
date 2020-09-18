import json, sets, sequtils, strformat, strutils
import arguments, exercises

type
  SyncDecision {.pure.} = enum
    yes, no, skip

proc syncDecision: SyncDecision =
  echo "Do you want to include the test case ([y]es/[n]o/[s]kip)?:"

  case stdin.readLine().toLowerAscii
    of "y", "yes":
      SyncDecision.yes
    of "n", "no":
      SyncDecision.no
    of "s", "skip":
      SyncDecision.skip
    else:
      echo "Unknown response. Skipping test case..."
      SyncDecision.skip

proc sync(exercise: Exercise): Exercise =
  result = exercise

  var included = result.tests.included
  var excluded = result.tests.excluded
  var missing = result.tests.missing

  echo &"[warn] {exercise.slug} is missing {exercise.tests.missing.len} test cases"  

  for testCase in exercise.testCases:
    if testCase.uuid notin exercise.tests.missing:
      continue

    echo &"""The following test case is missing:
{testCase.json.pretty}:
"""

    case syncDecision()
    of SyncDecision.yes:
      included.incl(testCase.uuid)
      missing.excl(testCase.uuid)
    of SyncDecision.no:
      excluded.incl(testCase.uuid)
      missing.excl(testCase.uuid)
    of SyncDecision.skip:
      discard

  result.tests = initExerciseTests(included, excluded, missing)

  writeFile(result)

proc sync(exercises: seq[Exercise]): seq[Exercise] =  
  for exercise in exercises:
    result.add(sync(exercise))

proc sync*(args: Arguments): void =
  echo "Syncing exercises..."

  let outOfSyncExercises = findOutOfSyncExercises(args)
  let syncedExercises = sync(outOfSyncExercises)

  if syncedExercises.anyIt(it.tests.missing.len > 0):
    quit("[warn] some exercises are still missing test cases", QuitFailure)
  else:
    quit("All exercises are synced!", QuitSuccess)
