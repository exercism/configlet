import std/[os, osproc, strformat, strutils, unittest]
import exec
import "."/[binary_helpers]

proc main =
  const psDir = getCacheDir() / "exercism" / "configlet" / "problem-specifications"
  const trackDir = testsDir / ".test_elixir_track_repo"

  # Setup: clone the problem-specifications repo, and checkout a known state
  setupExercismRepo("problem-specifications", psDir,
                    "daf620d47ed905409564dec5fa9610664e294bde") # 2021-06-18

  # Setup: clone a track repo, and checkout a known state
  setupExercismRepo("elixir", trackDir,
                    "8447eaeb5ae8bdd0ae94383e6ec5bcfa21a7f993") # 2021-10-28

  const
    createBase = &"{binaryPath} -t {trackDir} create"

  suite "create":
    test "concept exercise that already has been implemented (prints the expected output, and exits with 1)":
      const expectedOutput = fmt"""
        There already is a concept exercise with `lasagna` as the slug in the track config:
        {trackDir / "config.json"}
      """.unindent()
      execAndCheck(1, &"{createBase} --concept-exercise lasagna ", expectedOutput)

    test "practice exercise that already has been implemented (prints the expected output, and exits with 1)":
      const expectedOutput = fmt"""
        There already is a practice exercise with `leap` as the slug in the track config:
        {trackDir / "config.json"}
      """.unindent()
      execAndCheck(1, &"{createBase} --practice-exercise leap", expectedOutput)

main()
{.used.}
