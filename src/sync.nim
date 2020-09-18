import json, sets, sequtils, strformat, strutils
import arguments, exercises

type
  SyncDecision = enum
    yes, no, skip

proc syncDecision: SyncDecision =
  echo "Do you want to include the test case ([y]es/[n]o/[s]kip)?:"

  case stdin.readLine().toLowerAscii
    of "y", "yes":
      yes
    of "n", "no":
      no
    of "s", "skip":
      skip
    else:
      echo "Unknown response. Skipping test case..."
      skip

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
    of yes:
      included.incl(testCase.uuid)
      missing.excl(testCase.uuid)
    of no:
      excluded.incl(testCase.uuid)
      missing.excl(testCase.uuid)
    of skip:
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
