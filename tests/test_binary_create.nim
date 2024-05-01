import std/[os, osproc, re, strformat, strutils, unittest]
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
        Updating cached 'problem-specifications' data...
        There already is an exercise with `hangman` as the slug in the problem specifications repo
      """.unindent()
      execAndCheck(1, &"{createBase} --concept-exercise=hangman", expectedOutput)

    test "concept exercise with difficulty (prints the expected output, and exits with 1)":
      const expectedOutput = fmt"""
        The difficulty argument is not supported for concept exercises
      """.unindent()
      execAndCheck(1, &"{createBase} --concept-exercise=bar --difficulty 4", expectedOutput)

    test "create concept exercise (creates the exercise files, and exits with 0)":
      const expectedOutput = fmt"""
        Updating cached 'problem-specifications' data...
        Created concept exercise 'foo'.
      """.unindent()
      execAndCheck(0, &"{createBase} --concept-exercise=foo", expectedOutput)

      const expectedStatus = """
        M  config.json
        A  exercises/concept/foo/.docs/instructions.md
        A  exercises/concept/foo/.docs/introduction.md
        A  exercises/concept/foo/.meta/config.json
        A  exercises/concept/foo/.meta/exemplar.ex
        A  exercises/concept/foo/lib/foo.ex
        A  exercises/concept/foo/test/foo_test.exs
      """.unindent()
      testStatusThenReset(trackDir, expectedStatus)

    test "create concept exercise - offline (creates the exercise files, and exits with 0)":
      const expectedOutput = fmt"""
        Created concept exercise 'foo'.
      """.unindent()
      execAndCheck(0, &"{createBase} --concept-exercise=foo --offline", expectedOutput)

      const expectedStatus = """
        M  config.json
        A  exercises/concept/foo/.docs/instructions.md
        A  exercises/concept/foo/.docs/introduction.md
        A  exercises/concept/foo/.meta/config.json
        A  exercises/concept/foo/.meta/exemplar.ex
        A  exercises/concept/foo/lib/foo.ex
        A  exercises/concept/foo/test/foo_test.exs
      """.unindent()
      testStatusThenReset(trackDir, expectedStatus)

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

    test "create practice exercise with slug not matching prob-specs exercise (creates the exercise files, and exits with 0)":
      const expectedOutput = fmt"""
        Updating cached 'problem-specifications' data...
        Created practice exercise 'foo'.
      """.unindent()
      execAndCheck(0, &"{createBase} --practice-exercise=foo", expectedOutput)

      const expectedStatus = """
        M  config.json
        A  exercises/practice/foo/.docs/instructions.md
        A  exercises/practice/foo/.meta/config.json
        A  exercises/practice/foo/.meta/example.ex
        A  exercises/practice/foo/lib/foo.ex
        A  exercises/practice/foo/test/foo_test.exs
      """.unindent()
      testStatusThenReset(trackDir, expectedStatus)

    test "create practice exercise with slug not matching prob-specs exercise - offline (creates the exercise files, and exits with 0)":
      const expectedOutput = fmt"""
        Created practice exercise 'foo'.
      """.unindent()
      execAndCheck(0, &"{createBase} --practice-exercise=foo --offline", expectedOutput)

      const expectedStatus = """
        M  config.json
        A  exercises/practice/foo/.docs/instructions.md
        A  exercises/practice/foo/.meta/config.json
        A  exercises/practice/foo/.meta/example.ex
        A  exercises/practice/foo/lib/foo.ex
        A  exercises/practice/foo/test/foo_test.exs
      """.unindent()
      testStatusThenReset(trackDir, expectedStatus)

    test "create practice exercise with difficulty (creates the exercise files, and exits with 0)":
      const expectedOutput = fmt"""
        Updating cached 'problem-specifications' data...
        Created practice exercise 'foo'.
      """.unindent()
      execAndCheck(0, &"{createBase} --practice-exercise=foo --difficulty=5", expectedOutput)

      const expectedDiff = """
        --- config.json
        +++ config.json
        +      },
        +      {
        +        "slug": "foo",
        +        "name": "foo",
        +        "uuid": "<UUID>",
        +        "practices": [],
        +        "prerequisites": [],
        +        "difficulty": 5
      """.unindent().replace("\p", "\n")
      let diff = gitDiffConcise(trackDir).replace(re""""uuid": "[^"]+"""", """"uuid": "<UUID>"""")
      check diff == expectedDiff

      const expectedStatus = """
        M  config.json
        A  exercises/practice/foo/.docs/instructions.md
        A  exercises/practice/foo/.meta/config.json
        A  exercises/practice/foo/.meta/example.ex
        A  exercises/practice/foo/lib/foo.ex
        A  exercises/practice/foo/test/foo_test.exs
      """.unindent()
      testStatusThenReset(trackDir, expectedStatus)

    test "create practice exercise with author (creates the exercise files, and exits with 0)":
      const expectedOutput = fmt"""
        Updating cached 'problem-specifications' data...
        Created practice exercise 'foo'.
      """.unindent()
      execAndCheck(0, &"{createBase} --practice-exercise=foo --author=bar", expectedOutput)

      const expectedConfig = """
      {
        "authors": [
          "bar"
        ],
        "files": {
          "solution": [
            "lib/foo.ex"
          ],
          "test": [
            "test/foo_test.exs"
          ],
          "example": [
            ".meta/example.ex"
          ]
        },
        "blurb": ""
      }
      """.dedent(6).replace("\p", "\n")
      let configPath = trackDir / "exercises" / "practice" / "foo" / ".meta" / "config.json"
      let config = readFile(configPath)
      check config == expectedConfig

      const expectedStatus = """
        M  config.json
        A  exercises/practice/foo/.docs/instructions.md
        A  exercises/practice/foo/.meta/config.json
        A  exercises/practice/foo/.meta/example.ex
        A  exercises/practice/foo/lib/foo.ex
        A  exercises/practice/foo/test/foo_test.exs
      """.unindent()
      testStatusThenReset(trackDir, expectedStatus)

main()
{.used.}
