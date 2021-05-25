import std/[options, sets, strformat, strutils]
import ".."/[cli, logger]
import "."/exercises

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
  of modeInclude:
    sdIncludeTest
  of modeExclude:
    sdExcludeTest
  of modeChoose:
    chooseSyncDecision(testCase)

proc sync(exercise: Exercise, conf: Conf): Exercise =
  result = exercise

  let mode = conf.action.mode
  case mode
  of modeInclude:
    logNormal(&"[info] {exercise.slug}: included {exercise.tests.missing.len} missing test cases")
  of modeExclude:
    logNormal(&"[info] {exercise.slug}: excluded {exercise.tests.missing.len} missing test cases")
  of modeChoose:
    logNormal(&"[warn] {exercise.slug}: missing {exercise.tests.missing.len} test cases")

  var included = result.tests.included
  var excluded = result.tests.excluded
  var missing = result.tests.missing

  for testCase in exercise.testCases:
    let uuid = testCase.uuid
    if uuid in exercise.tests.missing:
      case syncDecision(testCase, mode)
      of sdIncludeTest:
        included.incl uuid
        missing.excl uuid
      of sdReplaceTest:
        included.incl uuid
        missing.excl uuid
        included.excl testCase.reimplements.get.uuid
        excluded.incl testCase.reimplements.get.uuid
      of sdExcludeTest:
        excluded.incl uuid
        missing.excl uuid
      of sdSkipTest:
        discard

  result.tests = initExerciseTests(included, excluded, missing)

  writeTestsToml(result, conf.trackDir)

proc syncIfNeeded(exercise: Exercise, conf: Conf): bool =
  ## Syncs the given `exercises` if it has missing tests, and returns `true` if
  ## it is up-to-date afterwards.
  case exercise.status
  of exOutOfSync:
    let syncedExercise = sync(exercise, conf)
    syncedExercise.status == exInSync
  of exInSync:
    logDetailed(&"[skip] {exercise.slug} is up-to-date")
    true
  of exNoCanonicalData:
    logDetailed(&"[skip] {exercise.slug} does not have canonical data")
    true

proc sync*(conf: Conf) =
  logNormal("Syncing exercises...")

  var everyExerciseIsSynced = true
  for exercise in findExercises(conf):
    let isExerciseSynced = syncIfNeeded(exercise, conf)
    if not isExerciseSynced:
      everyExerciseIsSynced = false

  if everyExerciseIsSynced:
    logNormal("All exercises are synced!")
    quit(QuitSuccess)
  else:
    logNormal("[warn] some exercises are still missing test cases")
    quit(QuitFailure)
