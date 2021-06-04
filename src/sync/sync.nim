import std/[options, sets, strformat, strutils]
import ".."/[cli, logger]
import "."/exercises

type
  SyncDecision = enum
    sdIncludeTest, sdExcludeTest, sdSkipTest, sdReplaceTest

proc chooseRegularSyncDecision(testCase: ExerciseTestCase): SyncDecision =
  echo &"""The following test case is missing:
{testCase.json.pretty()}

Do you want to include the test case ([y]es/[n]o/[s]kip)?
"""

  case stdin.readLine().toLowerAscii()
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
  echo &"""The following test case is missing:
{testCase.json.pretty()}

It reimplements this test case:
{testCase.reimplements.get().json.pretty()}

Do you want to replace the existing test case ([y]es/[n]o/[s]kip)?
"""

  case stdin.readLine().toLowerAscii()
  of "y", "yes":
    sdReplaceTest
  of "n", "no":
    sdExcludeTest
  of "s", "skip":
    sdSkipTest
  else:
    echo "Unknown response. Skipping test case..."
    sdSkipTest

proc syncDecision(testCase: ExerciseTestCase, mode: Mode): SyncDecision =
  case mode
  of modeInclude:
    sdIncludeTest
  of modeExclude:
    sdExcludeTest
  of modeChoose:
    if testCase.reimplements.isNone():
      chooseRegularSyncDecision(testCase)
    else:
      chooseReimplementsSyncDecision(testCase)

proc sync(exercise: Exercise, conf: Conf): Exercise =
  let mode = conf.action.mode
  case mode
  of modeInclude:
    logNormal(&"[info] {exercise.slug}: included {exercise.tests.missing.len} missing test cases")
  of modeExclude:
    logNormal(&"[info] {exercise.slug}: excluded {exercise.tests.missing.len} missing test cases")
  of modeChoose:
    logNormal(&"[warn] {exercise.slug}: missing {exercise.tests.missing.len} test cases")

  result = exercise

  for testCase in exercise.testCases:
    let uuid = testCase.uuid
    if uuid in exercise.tests.missing:
      case syncDecision(testCase, mode)
      of sdIncludeTest:
        result.tests.included.incl uuid
        result.tests.missing.excl uuid
      of sdReplaceTest:
        result.tests.included.incl uuid
        result.tests.missing.excl uuid
        result.tests.included.excl testCase.reimplements.get().uuid
        result.tests.excluded.incl testCase.reimplements.get().uuid
      of sdExcludeTest:
        result.tests.excluded.incl uuid
        result.tests.missing.excl uuid
      of sdSkipTest:
        discard

  writeTestsToml(result, conf.trackDir)

proc syncIfNeeded(exercise: Exercise, conf: Conf): bool =
  ## Syncs the given `exercises` if it has missing tests, and returns `true` if
  ## it is up-to-date afterwards.
  case exercise.status()
  of exOutOfSync:
    let syncedExercise = sync(exercise, conf)
    syncedExercise.status() == exInSync
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
