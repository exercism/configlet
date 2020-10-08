import std/[json, options, sequtils, sets, strformat, strutils]
import arguments, exercises, logger

type
  SyncDecision {.pure.} = enum
    IncludeTest, ExcludeTest, SkipTest, ReplaceTest

proc chooseRegularSyncDecision(testCase: ExerciseTestCase): SyncDecision =
  doAssert(testCase.reimplements.isNone)

  echo &"""The following test case is missing:"
{testCase.json.pretty}:

Do you want to include the test case ([y]es/[n]o/[s]kip)?:
"""

  case stdin.readLine().toLowerAscii
  of "y", "yes":
    SyncDecision.IncludeTest
  of "n", "no":
    SyncDecision.ExcludeTest
  of "s", "skip":
    SyncDecision.SkipTest
  else:
    echo "Unknown response. Skipping test case..."
    SyncDecision.SkipTest

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
    SyncDecision.ReplaceTest
  of "n", "no":
    SyncDecision.ExcludeTest
  of "s", "skip":
    SyncDecision.SkipTest
  else:
    echo "Unknown response. Skipping test case..."
    SyncDecision.SkipTest

proc chooseSyncDecision(testCase: ExerciseTestCase): SyncDecision =
  if testCase.reimplements.isNone:
    chooseRegularSyncDecision(testCase)
  else:
    chooseReimplementsSyncDecision(testCase)

proc syncDecision(testCase: ExerciseTestCase, mode: Mode): SyncDecision =
  case mode
  of Mode.IncludeMissing:
    SyncDecision.IncludeTest
  of Mode.ExcludeMissing:
    SyncDecision.ExcludeTest
  of Mode.Choose:
    chooseSyncDecision(testCase)

proc sync(exercise: Exercise, mode: Mode): Exercise =
  result = exercise

  case mode
  of Mode.IncludeMissing:
    logNormal(&"[info] {exercise.slug}: included {exercise.tests.missing.len} missing test cases")
  of Mode.ExcludeMissing:
    logNormal(&"[info] {exercise.slug}: excluded {exercise.tests.missing.len} missing test cases")
  of Mode.Choose:
    logNormal(&"[warn] {exercise.slug}: missing {exercise.tests.missing.len} test cases")

  var included = result.tests.included
  var excluded = result.tests.excluded
  var missing = result.tests.missing

  for testCase in exercise.testCases:
    if testCase.uuid notin exercise.tests.missing:
      continue

    case syncDecision(testCase, mode)
    of SyncDecision.IncludeTest:
      included.incl(testCase.uuid)
      missing.excl(testCase.uuid)
    of SyncDecision.ReplaceTest:
      included.incl(testCase.uuid)
      missing.excl(testCase.uuid)
      included.excl(testCase.reimplements.get.uuid)
      excluded.incl(testCase.reimplements.get.uuid)
    of SyncDecision.ExcludeTest:
      excluded.incl(testCase.uuid)
      missing.excl(testCase.uuid)
    of SyncDecision.SkipTest:
      discard

  result.tests = initExerciseTests(included, excluded, missing)

  writeFile(result)

proc sync(exercises: seq[Exercise], mode: Mode): seq[Exercise] =
  for exercise in exercises:
    case exercise.status
    of ExerciseStatus.OutOfSync:
      result.add(sync(exercise, mode))
    of ExerciseStatus.InSync:
      logDetailed(&"[skip] {exercise.slug} is up-to-date")
    of ExerciseStatus.NoCanonicalData:
      logDetailed(&"[skip] {exercise.slug} does not have canonical data")

proc sync*(args: Arguments) =
  logNormal("Syncing exercises...")

  let exercises = findExercises(args)
  let syncedExercises = sync(exercises, args.mode)

  if syncedExercises.anyIt(it.status == ExerciseStatus.OutOfSync):
    logNormal("[warn] some exercises are still missing test cases")
    quit(QuitFailure)
  else:
    logNormal("All exercises are synced!")
    quit(QuitSuccess)
