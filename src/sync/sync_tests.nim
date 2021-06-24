import std/[options, sets, strformat, strutils]
import ".."/[cli, logger]
import "."/[exercises, probspecs]

proc checkTests*(exercises: seq[Exercise], seenUnsynced: var set[SyncKind]) =
  for exercise in exercises:
    let numMissing = exercise.tests.missing.len
    let wording = if numMissing == 1: "test case" else: "test cases"

    case exercise.status()
    of exOutOfSync:
      seenUnsynced.incl skTests
      logNormal(&"[warn] {exercise.slug}: missing {numMissing} {wording}")
      for testCase in exercise.testCases:
        if testCase.uuid in exercise.tests.missing:
          logNormal(&"       - {testCase.description} ({testCase.uuid})")
    of exInSync:
      logDetailed(&"[skip] {exercise.slug}: up-to-date")
    of exNoCanonicalData:
      logDetailed(&"[skip] {exercise.slug}: does not have canonical data")

type
  SyncDecision = enum
    sdIncludeTest, sdExcludeTest, sdSkipTest, sdReplaceTest

proc writeBlankLines =
  stderr.write "\n\n"

proc chooseRegularSyncDecision(testCase: ExerciseTestCase): SyncDecision =
  stderr.write &"""
The following test case is missing:
{testCase.json.pretty()}

Do you want to include the test case ([y]es/[n]o/[s]kip)? """

  case stdin.readLine().toLowerAscii()
  of "y", "yes":
    writeBlankLines()
    sdIncludeTest
  of "n", "no":
    writeBlankLines()
    sdExcludeTest
  of "s", "skip":
    writeBlankLines()
    sdSkipTest
  else:
    stderr.writeLine "Unknown response. Skipping test case..."
    writeBlankLines()
    sdSkipTest

proc chooseReimplementsSyncDecision(testCase: ExerciseTestCase): SyncDecision =
  stderr.write &"""
The following test case is missing:
{testCase.json.pretty()}

It reimplements this test case:
{testCase.reimplements.get().json.pretty()}

Do you want to replace the existing test case ([y]es/[n]o/[s]kip)? """

  case stdin.readLine().toLowerAscii()
  of "y", "yes":
    writeBlankLines()
    sdReplaceTest
  of "n", "no":
    writeBlankLines()
    sdExcludeTest
  of "s", "skip":
    writeBlankLines()
    sdSkipTest
  else:
    stderr.writeLine "Unknown response. Skipping test case..."
    writeBlankLines()
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
  let numMissing = exercise.tests.missing.len
  let wording = if numMissing == 1: "test case" else: "test cases"
  case mode
  of modeInclude:
    logNormal(&"[info] {exercise.slug}: included {numMissing} missing {wording}")
  of modeExclude:
    logNormal(&"[info] {exercise.slug}: excluded {numMissing} missing {wording}")
  of modeChoose:
    logNormal(&"[warn] {exercise.slug}: missing {numMissing} {wording}")

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

proc updateTests*(exercises: seq[Exercise], conf: Conf,
                  seenUnsynced: var set[SyncKind]) =
  logNormal("Updating tests...")

  var everyExerciseIsSynced = true

  for exercise in exercises:
    let isExerciseSynced = syncIfNeeded(exercise, conf)
    if not isExerciseSynced:
      everyExerciseIsSynced = false

  if everyExerciseIsSynced:
    seenUnsynced.excl skTests
  else:
    seenUnsynced.incl skTests
