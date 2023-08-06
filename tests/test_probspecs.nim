# This module contains tests for `src/probspecs.nim`
import std/[json, os, strformat, tables, unittest]
import cli, exec, sync/probspecs

proc getProbSpecsExercises(probSpecsDir: ProbSpecsDir): Table[string,
    seq[ProbSpecsTestCase]] =
  ## Returns a Table containing the slug and corresponding canonical tests for
  ## each exercise in `probSpecsDir`.
  let pattern = joinPath(probSpecsDir.string, "exercises", "*")
  for dir in walkDirs(pattern):
    let slug = lastPathPart(dir)
    result[slug] = getCanonicalTests(probSpecsDir, slug)

proc main =
  let psDir = getCacheDir() / "exercism" / "configlet" / "problem-specifications"
  removeDir psDir

  for psCacheKind in ["no cache", "cache exists"]:
    suite &"getCanonicalTests: {psCacheKind}":
      let action = Action.init(actSync)
      let conf = Conf.init(action)
      let probSpecsDir = ProbSpecsDir.init(conf)
      let probSpecsExercises = getProbSpecsExercises(probSpecsDir)

      test "can return the exercises":
        check:
          probSpecsExercises.len >= 116

      test "the first exercise with canonical data is as expected":
        let exercise = probSpecsExercises["accumulate"]

        check:
          exercise.len >= 5 # Tests are never removed.

      test "the first test case of first exercise is as expected":
        let firstTestCase = probSpecsExercises["accumulate"][0].JsonNode
        let firstTestCaseExpected = """{
      "uuid": "64d97c14-36dd-44a8-9621-2cecebd6ed23",
      "description": "accumulate empty",
      "property": "accumulate",
      "input": {
        "list": [],
        "accumulator": "(x) => x * x"
      },
      "expected": []
    }""".parseJson()

        check:
          firstTestCase == firstTestCaseExpected

      test "the second exercise with canonical data is as expected":
        let exercise = probSpecsExercises["acronym"]

        check:
          exercise.len >= 9 # Tests are never removed.

      test "the first test case of second exercise is as expected":
        let firstTestCase = probSpecsExercises["acronym"][0].JsonNode
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

main()
{.used.}
