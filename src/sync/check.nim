import std/[sets, strformat]
import ".."/[cli, logger]
import "."/exercises

proc check*(conf: Conf) =
  logNormal("Checking exercises...")

  var hasOutOfSync = false

  for exercise in findExercises(conf):
    case exercise.status()
    of exOutOfSync:
      hasOutOfSync = true
      logNormal(&"[warn] {exercise.slug}: missing {exercise.tests.missing.len} test cases")
      for testCase in exercise.testCases:
        if testCase.uuid in exercise.tests.missing:
          logNormal(&"       - {testCase.description} ({testCase.uuid})")
    of exInSync:
      logDetailed(&"[skip] {exercise.slug}: up-to-date")
    of exNoCanonicalData:
      logDetailed(&"[skip] {exercise.slug}: does not have canonical data")

  if hasOutOfSync:
    logNormal("[warn] some exercises are missing test cases")
    quit(QuitFailure)
  else:
    logNormal("All exercises are up-to-date!")
    quit(QuitSuccess)
