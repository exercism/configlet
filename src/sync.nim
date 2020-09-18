import json, sets, sequtils, strformat, strutils
import arguments, exercises, logger

type
  SyncDecision {.pure.} = enum
    includeTest, excludeTest, skipTest

proc chooseSyncDecision(testCase: ExerciseTestCase): SyncDecision =
  echo &"""The following test case is missing:
{testCase.json.pretty}:
Do you want to include the test case ([y]es/[n]o/[s]kip)?:
"""

  case stdin.readLine().toLowerAscii
    of "y", "yes":
      SyncDecision.includeTest
    of "n", "no":
      SyncDecision.excludeTest
    of "s", "skip":
      SyncDecision.skipTest
    else:
      echo "Unknown response. Skipping test case..."
      SyncDecision.skipTest

proc syncDecision(testCase: ExerciseTestCase, mode: Mode): SyncDecision =
  case mode
  of includeMissing:
    SyncDecision.includeTest
  of excludeMissing:
    SyncDecision.excludeTest
  of choose:
    chooseSyncDecision(testCase)

proc sync(exercise: Exercise, mode: Mode): Exercise =
  result = exercise

  case mode
  of includeMissing:
    logNormal(&"[info] {exercise.slug}: included {exercise.tests.missing.len} missing test cases")
  of excludeMissing:
    logNormal(&"[info] {exercise.slug}: excluded {exercise.tests.missing.len} missing test cases")
  of choose:
    logNormal(&"[warn] {exercise.slug}: missing {exercise.tests.missing.len} test cases")

  var included = result.tests.included
  var excluded = result.tests.excluded
  var missing = result.tests.missing

  for testCase in exercise.testCases:
    if testCase.uuid notin exercise.tests.missing:
      continue

    case syncDecision(testCase, mode)
    of SyncDecision.includeTest:
      included.incl(testCase.uuid)
      missing.excl(testCase.uuid)
    of SyncDecision.excludeTest:
      excluded.incl(testCase.uuid)
      missing.excl(testCase.uuid)
    of SyncDecision.skipTest:
      discard

  result.tests = initExerciseTests(included, excluded, missing)

  writeFile(result)

proc sync(exercises: seq[Exercise], mode: Mode): seq[Exercise] =
  for exercise in exercises:
    case exercise.status
    of ExerciseStatus.outOfSync:
      result.add(sync(exercise, mode))
    of ExerciseStatus.inSync:
      logDetailed(&"[skip] {exercise.slug} is up-to-date")
    of ExerciseStatus.noCanonicalData:
      logDetailed(&"[skip] {exercise.slug} does not have canonical data")

proc sync*(args: Arguments): void =
  logNormal("Syncing exercises...")

  let exercises = findExercises(args)
  let syncedExercises = sync(exercises, args.mode)

  if syncedExercises.anyIt(it.status == ExerciseStatus.outOfSync):
    logNormal("[warn] some exercises are still missing test cases")
    quit(QuitFailure)
  else:
    logNormal("All exercises are synced!")
    quit(QuitSuccess)
