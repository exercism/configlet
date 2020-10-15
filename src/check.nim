import std/[sequtils, sets, strformat]
import cli, exercises, logger

proc check*(conf: Conf) =
  logNormal("Checking exercises...")

  let exercises = findExercises(conf)

  for exercise in exercises:
    case exercise.status
    of exOutOfSync:
      logNormal(&"[warn] {exercise.slug}: missing {exercise.tests.missing.len} test cases")
      let missingCases = exercise.testCases
        .filterIt(it.uuid in exercise.tests.missing)
      for testCase in missingCases:
        logNormal(&"       - {testCase.description} ({testCase.uuid})")
    of exInSync:
      logDetailed(&"[skip] {exercise.slug}: up-to-date")
    of exNoCanonicalData:
      logDetailed(&"[skip] {exercise.slug}: does not have canonical data")

  if exercises.anyIt(it.status == exOutOfSync):
    logNormal("[warn] some exercises are missing test cases")
    quit(QuitFailure)
  else:
    logNormal("All exercises are up-to-date!")
    quit(QuitSuccess)
