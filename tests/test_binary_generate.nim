import std/[os, osproc, strformat, strutils, unittest]
import exec
import "."/[binary_helpers]

proc prepareIntroductionFiles(trackDir, placeholder: string; removeIntro: bool) =
  # Writes an `introduction.md.tpl` file for the `bird-count` Concept Exercise,
  # containing the given `placeholder`. Also removes the `introduction.md` file
  # if `removeIntro` is `true`.
  let
    docsPath = trackDir / "exercises" / "concept" / "bird-count" / ".docs"
    introPath = docsPath / "introduction.md"
    templatePath = introPath & ".tpl"
    templateContents = fmt"""
      # Introduction

      {placeholder}
    """.unindent()
  writeFile(templatePath, templateContents)
  if removeIntro:
    removeFile(introPath)

proc main =
  suite "generate":
    const trackDir = testsDir / ".test_elixir_track_repo"
    let generateCmd = &"{binaryPath} -t {trackDir} generate"
    let generateCmdUpdate = &"{generateCmd} --update"
    let generateCmdUpdateYes = &"{generateCmdUpdate} --yes"

    # Setup: clone a track repo, and checkout a known state
    setupExercismRepo("elixir", trackDir,
                      "91ccf91940f32aff3726c772695b2de167d8192a") # 2022-06-12

    test "`configlet generate` exits with 0 when there are no `.md.tpl` files":
      const expectedOutput = fmt"""
        Every introduction file is up-to-date!
      """.unindent().replace("\p", "\n")
      execAndCheck(0, generateCmdUpdateYes, expectedOutput)

    test "and does not make a change":
      checkNoDiff(trackDir)

    # Valid placeholder syntax without spaces, and invalid slug
    prepareIntroductionFiles(trackDir, "%{concept:not-a-real-concept-slug}",
                             removeIntro = false)

    test "`configlet generate` exits with 1 for an invalid placeholder usage":
      execAndCheckExitCode(1, generateCmdUpdateYes)

    test "and does not make a change":
      checkNoDiff(trackDir)

    # Valid placeholder syntax without spaces, and valid slug
    prepareIntroductionFiles(trackDir, "%{concept:recursion}",
                             removeIntro = true)

    test "`configlet generate` exits with 0 for a valid `.md.tpl` file":
      const expectedOutput = fmt"""
        Missing: {"exercises"/"concept"/"bird-count"/".docs"/"introduction.md"}
        Generated 1 file
      """.unindent().replace("\p", "\n")
      execAndCheck(0, generateCmdUpdateYes, expectedOutput)

    test "and writes the `introduction.md` file as expected":
      checkNoDiff(trackDir)

    # Valid placeholder syntax with spaces, and valid slug
    prepareIntroductionFiles(trackDir, "%{ concept : recursion }",
                             removeIntro = true)

    test "`configlet generate` exits with 0 for valid placeholder usage with spaces, intro does not exist":
      const expectedOutput = fmt"""
        Missing: {"exercises"/"concept"/"bird-count"/".docs"/"introduction.md"}
        Generated 1 file
      """.unindent().replace("\p", "\n")
      execAndCheck(0, generateCmdUpdateYes, expectedOutput)

    test "and writes the `introduction.md` file as expected":
      checkNoDiff(trackDir)

    # Valid placeholder syntax with spaces, and valid slug
    prepareIntroductionFiles(trackDir, "%{ concept : atoms }",
                             removeIntro = false)

    test "`configlet generate` exits with 0 for valid placeholder usage with spaces, intro exists":
      const expectedOutput = fmt"""
        Outdated: {"exercises"/"concept"/"bird-count"/".docs"/"introduction.md"}
        Generated 1 file
      """.unindent().replace("\p", "\n")
      execAndCheck(0, generateCmdUpdateYes, expectedOutput)

    test "and writes the `introduction.md` file as expected":
      const expectedDiff = """
        --- exercises/concept/bird-count/.docs/introduction.md
        +++ exercises/concept/bird-count/.docs/introduction.md
        -## Recursion
        +## Atoms
        -Recursive functions are functions that call themselves.
        -
        -A recursive function needs to have at least one _base case_ and at least one _recursive case_.
        -
        -A _base case_ returns a value without calling the function again. A _recursive case_ calls the function again, modifying the input so that it will at some point match the base case.
        -
        -Very often, each case is written in its own function clause.
        +Elixir's `atom` type represents a fixed constant. An atom's value is simply its own name. This gives us a type-safe way to interact with data. Atoms can be defined as follows:
        -# base case
        -def count([]), do: 0
        -
        -# recursive case
        -def count([_head | tail]), do: 1 + count(tail)
        +# All atoms are preceded with a ':' then follow with alphanumeric snake-cased characters
        +variable = :an_atom
        +
        +_Atoms_ are internally represented by an integer in a lookup table, which are set automatically. It is not possible to change this internal value.
      """.unindent().replace("\p", "\n")
      testDiffThenRestore(trackDir, expectedDiff, "exercises"/"concept"/"bird-count"/".docs"/"introduction.md")
      removeFile(trackDir / "exercises"/"concept"/"bird-count"/".docs"/"introduction.md.tpl")

main()
{.used.}
