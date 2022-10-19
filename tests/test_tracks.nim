# This file implements tests for `src/tracks.nim`
import std/[os, sequtils, sets, unittest]
import "."/[cli, exec, sync/tracks]

const
  testsDir = currentSourcePath().parentDir()

proc main =
  suite "findPracticeExercises":
    const trackDir = testsDir / ".test_nim_track_repo"
    setupExercismRepo("nim", trackDir,
                      "736245965db724cafc5ec8e9dcae83c850b7c5a8") # 2021-10-22

    let conf = Conf(
      action: Action.init(actSync, scope = {skTests}),
      trackDir: trackDir,
    )
    let practiceExercises = toSeq findPracticeExercises(conf)

    test "returns the expected number of exercises":
      check:
        practiceExercises.len == 67

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
        practiceExercises[19] == expectedHelloWorld

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
        practiceExercises[64] == expectedTwoFer

main()
{.used.}
