import std/[sets, strformat]
import ".."/[cli, logger]
import "."/exercises

proc checkDocs(exercise: Exercise, seenUnsynced: var set[SyncKind]) =
  if false:
    seenUnsynced.incl skDocs

proc checkFilepaths(exercise: Exercise, seenUnsynced: var set[SyncKind]) =
  if false:
    seenUnsynced.incl skFilepaths

proc checkMetadata(exercise: Exercise, seenUnsynced: var set[SyncKind]) =
  if false:
    seenUnsynced.incl skMetadata

proc checkTests(exercise: Exercise, seenUnsynced: var set[SyncKind]) =
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

proc explain(syncKind: SyncKind): string =
  case syncKind
  of skDocs: "have unsynced docs"
  of skFilepaths: "have unsynced filepaths"
  of skMetadata: "have unsynced metadata"
  of skTests: "are missing test cases"

proc check*(conf: Conf) =
  logNormal("Checking exercises...")

  var seenUnsynced: set[SyncKind]

  for exercise in findExercises(conf):
    if skDocs in conf.action.scope:
      checkDocs(exercise, seenUnsynced)

    if skFilepaths in conf.action.scope:
      checkFilepaths(exercise, seenUnsynced)

    if skMetadata in conf.action.scope:
      checkMetadata(exercise, seenUnsynced)

    if skTests in conf.action.scope:
      checkTests(exercise, seenUnsynced)

  if seenUnsynced.len > 0:
    for syncKind in seenUnsynced:
      logNormal(&"[warn] some exercises {explain(syncKind)}")
    quit(QuitFailure)
  else:
    logNormal("All exercises are up-to-date!")
    quit(QuitSuccess)
