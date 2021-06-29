# This file implements tests for `src/tracks.nim`
import std/[os, sequtils, sets, strformat, unittest]
import "."/[cli, exec, sync/tracks]

proc main =
  suite "findPracticeExercises":
    const trackDir = ".test_tracks_nim_track_repo"
    setupExercismRepo("nim", trackDir, "6e909c9e5338cd567c20224069df00e031fb2efa")

    let conf = Conf(
      action: initAction(actSync),
      trackDir: trackDir,
    )
    let practiceExercises = toSeq findPracticeExercises(conf)

    test "returns the expected number of exercises":
      check:
        practiceExercises.len == 68

    test "returns the expected object for `hello-world`":
      const expectedHelloWorld =
        PracticeExercise(
          slug: PracticeExerciseSlug("hello-world"),
          tests: PracticeExerciseTests(
            included: ["af9ffe10-dc13-42d8-a742-e7bdafac449d"].toHashSet(),
            excluded: initHashSet[string](0)
          )
        )

      check:
        practiceExercises[20] == expectedHelloWorld

    test "returns the expected object for `two-fer`":
      const expectedTwoFer =
        PracticeExercise(
          slug: PracticeExerciseSlug("two-fer"),
          tests: PracticeExerciseTests(
            included: ["1cf3e15a-a3d7-4a87-aeb3-ba1b43bc8dce",
                       "3549048d-1a6e-4653-9a79-b0bda163e8d5",
                       "b4c6dbb8-b4fb-42c2-bafd-10785abe7709"].toHashSet(),
            excluded: initHashSet[string](0)
          )
        )

      check:
        practiceExercises[65] == expectedTwoFer

    # Try to remove the track directory, but allow the tests to pass if there
    # was an error removing it.
    # This resolves a CI failure on Windows.
    # "The process cannot access the file because it is being used by another
    # process."
    try:
      sleep(1000)
      removeDir(trackDir)
    except CatchableError:
      stderr.writeLine &"Error: could not remove the directory: {trackDir}"
      stderr.writeLine getCurrentExceptionMsg()

main()
{.used.}
