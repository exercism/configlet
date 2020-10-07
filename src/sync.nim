import std/[json, options, sequtils, sets, strformat, strutils]
import arguments, exercises, logger

type
  SyncDecision = enum
    sdIncludeTest, sdExcludeTest, sdSkipTest, sdReplaceTest

proc chooseRegularSyncDecision(testCase: ExerciseTestCase): SyncDecision =
  doAssert(testCase.reimplements.isNone)

  echo &"""The following test case is missing:"
{testCase.json.pretty}:

Do you want to include the test case ([y]es/[n]o/[s]kip)?:
"""

  case stdin.readLine().toLowerAscii
  of "y", "yes":
    sdIncludeTest
  of "n", "no":
    sdExcludeTest
  of "s", "skip":
    sdSkipTest
  else:
    echo "Unknown response. Skipping test case..."
    sdSkipTest

proc chooseReimplementsSyncDecision(testCase: ExerciseTestCase): SyncDecision =
  doAssert(testCase.reimplements.isSome)

  echo &"""The following test case is missing:"
{testCase.json.pretty}:

It reimplements this test case:
{testCase.reimplements.get.json.pretty}:

Do you want to replace the existing test case ([y]es/[n]o/[s]kip)?:
"""

  case stdin.readLine().toLowerAscii
  of "y", "yes":
    sdReplaceTest
  of "n", "no":
    sdExcludeTest
  of "s", "skip":
    sdSkipTest
  else:
    echo "Unknown response. Skipping test case..."
    sdSkipTest

proc chooseSyncDecision(testCase: ExerciseTestCase): SyncDecision =
  if testCase.reimplements.isNone:
    chooseRegularSyncDecision(testCase)
  else:
    chooseReimplementsSyncDecision(testCase)

proc syncDecision(testCase: ExerciseTestCase, mode: Mode): SyncDecision =
  case mode
  of modeIncludeMissing:
    sdIncludeTest
  of modeExcludeMissing:
    sdExcludeTest
  of modeChoose:
    chooseSyncDecision(testCase)

proc sync(exercise: Exercise, mode: Mode): Exercise =
  result = exercise

  case mode
  of modeIncludeMissing:
    logNormal(&"[info] {exercise.slug}: included {exercise.tests.missing.len} missing test cases")
  of modeExcludeMissing:
    logNormal(&"[info] {exercise.slug}: excluded {exercise.tests.missing.len} missing test cases")
  of modeChoose:
    logNormal(&"[warn] {exercise.slug}: missing {exercise.tests.missing.len} test cases")

  var included = result.tests.included
  var excluded = result.tests.excluded
  var missing = result.tests.missing

  for testCase in exercise.testCases:
    if testCase.uuid notin exercise.tests.missing:
      continue

    case syncDecision(testCase, mode)
    of sdIncludeTest:
      included.incl(testCase.uuid)
      missing.excl(testCase.uuid)
    of sdReplaceTest:
      included.incl(testCase.uuid)
      missing.excl(testCase.uuid)
      included.excl(testCase.reimplements.get.uuid)
      excluded.incl(testCase.reimplements.get.uuid)
    of sdExcludeTest:
      excluded.incl(testCase.uuid)
      missing.excl(testCase.uuid)
    of sdSkipTest:
      discard

  result.tests = initExerciseTests(included, excluded, missing)

  writeFile(result)

proc sync(exercises: seq[Exercise], mode: Mode): seq[Exercise] =
  for exercise in exercises:
    case exercise.status
    of exOutOfSync:
      result.add(sync(exercise, mode))
    of exInSync:
      logDetailed(&"[skip] {exercise.slug} is up-to-date")
    of exNoCanonicalData:
      logDetailed(&"[skip] {exercise.slug} does not have canonical data")

proc sync*(args: Arguments) =
  logNormal("Syncing exercises...")

  let exercises = findExercises(args)
  let syncedExercises = sync(exercises, args.mode)

  if syncedExercises.anyIt(it.status == exOutOfSync):
    logNormal("[warn] some exercises are still missing test cases")
    quit(QuitFailure)
  else:
    logNormal("All exercises are synced!")
    quit(QuitSuccess)
