import std/[sequtils, sets, strformat]
import arguments, exercises, logger

proc check*(args: Arguments) =
  logNormal("Checking exercises...")

  let exercises = findExercises(args)

  for exercise in exercises:
    case exercise.status
    of ExerciseStatus.OutOfSync:
      logNormal(&"[warn] {exercise.slug}: missing {exercise.tests.missing.len} test cases")
    of ExerciseStatus.InSync:
      logDetailed(&"[skip] {exercise.slug}: up-to-date")
    of ExerciseStatus.NoCanonicalData:
      logDetailed(&"[skip] {exercise.slug}: does not have canonical data")

  if exercises.anyIt(it.status == ExerciseStatus.OutOfSync):
    logNormal("[warn] some exercises are missing test cases")
    quit(QuitFailure)
  else:
    logNormal("All exercises are up-to-date!")
    quit(QuitSuccess)
