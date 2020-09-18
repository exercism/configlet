import json, strformat, strutils
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

proc sync(exercise: Exercise): void =
  var newIncludes = newSeq[TestCase]()
  var newExcludes = newSeq[TestCase]()

  for missingTestCase in exercise.testCases.missing:
    echo &"""The following test case is missing:
{missingTestCase.json.pretty}:
"""

    case syncDecision()
    of yes:
      newIncludes.add(missingTestCase)
    of no:
      newExcludes.add(missingTestCase)
    of skip:
      discard

  let updatedExercise = initExercise(exercise, newIncludes, newExcludes)
  writeTestsToFile(updatedExercise)

proc sync*(args: Arguments): void =
  echo "Syncing exercises..."

  let outOfSyncExercises = findOutOfSyncExercises(args)

  for outOfSyncExercise in outOfSyncExercises:
    echo &"[warn] {outOfSyncExercise.slug} is missing {outofSyncExercise.testCases.missing.len} test cases"
    sync(outOfSyncExercise)

  # TODO: re-check status
  if outOfSyncExercises.len > 0:
    quit("[warn] some exercises are missing test cases", QuitFailure)
  else:
    quit("All exercises are synced and up-to-date!", QuitSuccess)