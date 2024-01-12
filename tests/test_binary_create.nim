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
                    "10a13b6b3b5491511c6e50f3a907d014f263221f") # 2024-01-10

  const
    createBase = &"{binaryPath} -t {trackDir} create"

  suite "create":
    test "missing argument to determine what to create (prints the expected output, and exits with 1)":
      const expectedOutput = fmt"""
        Please specify `--practice-exercise <slug>`, `--concept-exercise <slug>`, `--article <slug>` or `--approach <slug>`
      """.unindent()
      execAndCheck(1, &"{createBase}", expectedOutput)

    test "concept exercise slug matches existing concept exercise (prints the expected output, and exits with 1)":
      const expectedOutput = fmt"""
        There already is a concept exercise with `lasagna` as the slug in the track config:
        {trackDir / "config.json"}
      """.unindent()
      execAndCheck(1, &"{createBase} --concept-exercise=lasagna", expectedOutput)

    test "concept exercise slug matches existing practice exercise (prints the expected output, and exits with 1)":
      const expectedOutput = fmt"""
        There already is a practice exercise with `leap` as the slug in the track config:
        {trackDir / "config.json"}
      """.unindent()
      execAndCheck(1, &"{createBase} --concept-exercise=leap", expectedOutput)

    test "concept exercise slug matches prob-specs exercise (prints the expected output, and exits with 1)":
      const expectedOutput = fmt"""
        There already is an exercise with `hangman` as the slug in the problem specifications repo
      """.unindent()
      execAndCheck(1, &"{createBase} --concept-exercise=hangman", expectedOutput)

    test "practice exercise slug matches existing concept exercise (prints the expected output, and exits with 1)":
      const expectedOutput = fmt"""
        There already is a concept exercise with `lasagna` as the slug in the track config:
        {trackDir / "config.json"}
      """.unindent()
      execAndCheck(1, &"{createBase} --practice-exercise=lasagna", expectedOutput)

    test "practice exercise slug matches existing practice exercise (prints the expected output, and exits with 1)":
      const expectedOutput = fmt"""
        There already is a practice exercise with `leap` as the slug in the track config:
        {trackDir / "config.json"}
      """.unindent()
      execAndCheck(1, &"{createBase} --practice-exercise=leap", expectedOutput)

    test "create practice exercise with slug matching prob-specs exercise (creates the exercise files, and exits with 0)":
      const expectedOutput = fmt"""
        Created practice exercise 'hangman'.
      """.unindent()
      execAndCheck(0, &"{createBase} --practice-exercise=hangman", expectedOutput)

      const expectedDiff = """--- config.json
+++ config.json
+      },
+      {
+        "slug": "hangman",
+        "name": "Hangman",
+        "uuid": "d78c1f28-f436-4d65-9c88-03f6ab662bcd",
+        "practices": [],
+        "prerequisites": [],
+        "difficulty": 1
      """.unindent()

      testDiffThenRestore(trackDir, expectedDiff, trackDir / "config.json")

      # let diff = gitDiffConcise(trackDir)
      # echo diff

      # check diff == expectedDiff

      # let exerciseDir = trackDir / "exercises" / "practice" / "hangman"
      # let expectedFiles = [
      #   exerciseDir / ".docs" / "instructions.md",
      #   exerciseDir / ".meta" / "config.json",
      #   exerciseDir / ".meta" / "example.ex",
      #   exerciseDir / "lib" / "hangman.ex",
      #   exerciseDir / "test" / "hangman_test.exs"
      # ]
      
      # for expectedFile in expectedFiles:
      #   check fileExists(expectedFile)

main()
{.used.}
