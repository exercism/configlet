import std/[sets, strformat]
import ".."/[cli, logger]
import "."/exercises

proc checkTests(exercise: Exercise, seenMissingTests: var bool) =
  let numMissing = exercise.tests.missing.len
  let wording = if numMissing == 1: "test case" else: "test cases"

  case exercise.status()
  of exOutOfSync:
    seenMissingTests = true
    logNormal(&"[warn] {exercise.slug}: missing {numMissing} {wording}")
    for testCase in exercise.testCases:
      if testCase.uuid in exercise.tests.missing:
        logNormal(&"       - {testCase.description} ({testCase.uuid})")
  of exInSync:
    logDetailed(&"[skip] {exercise.slug}: up-to-date")
  of exNoCanonicalData:
    logDetailed(&"[skip] {exercise.slug}: does not have canonical data")

proc check*(conf: Conf) =
  logNormal("Checking exercises...")

  var seenMissingTests = false

  for exercise in findExercises(conf):
    if skTests in conf.action.scope:
      checkTests(exercise, seenMissingTests)

  if seenMissingTests:
    logNormal("[warn] some exercises are missing test cases")
    quit(QuitFailure)
  else:
    logNormal("All exercises are up-to-date!")
    quit(QuitSuccess)
