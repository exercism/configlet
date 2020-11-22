# This module contains tests for `src/probspecs.nim`
import std/[json, os, osproc, strformat, unittest]
import cli, probspecs

type
  ProblemSpecsDir = enum
    psFresh = "fresh clone"
    psExisting = "existing dir (simulate the `--prob-specs-dir` option)"

proc main =
  let existingDir = getTempDir() / "test_probspecs_problem-specifications"
  removeDir(existingDir)

  for ps in ProblemSpecsDir:
    suite &"findProbSpecsExercises: {ps}":
      if ps == psExisting:
        let cmd = "git clone --depth 1 --quiet " &
                  "https://github.com/exercism/problem-specifications/ " &
                  existingDir
        test "can make our own clone for later use as an \"existing dir\"":
          check:
            execCmd(cmd) == 0

      let probSpecsDir =
        case ps
        of psFresh: ""
        of psExisting: existingDir

      let action = initAction(actSync, probSpecsDir)
      let conf = initConf(action)
      let probSpecsExercises = findProbSpecsExercises(conf)

      test "can return the exercises":
        check:
          probSpecsExercises.len >= 116

      test "the first exercise is as expected":
        let exercise = probSpecsExercises[0]

        check:
          exercise.slug == "acronym" # The first exercise with canonical data.
          exercise.testCases.len >= 9 # Tests are never removed.

      test "the first test case is as expected":
        let firstTestCase = probSpecsExercises[0].testCases[0].json
        let firstTestCaseExpected = """{
          "uuid": "1e22cceb-c5e4-4562-9afe-aef07ad1eaf4",
          "description": "basic",
          "property": "abbreviate",
          "input": {
            "phrase": "Portable Network Graphics"
          },
          "expected": "PNG"
        }""".parseJson()

        check:
          firstTestCase == firstTestCaseExpected

  removeDir(existingDir)

main()
{.used.}
