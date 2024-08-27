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
        Outdated: {"exercises"/"concept"/"bird-count"/".docs"/"introduction.md"}
        Generated 1 file
      """.unindent().replace("\p", "\n")
      execAndCheck(0, generateCmdUpdateYes, expectedOutput)

    test "and writes the `introduction.md` file as expected":
      checkNoDiff(trackDir)

    # Valid placeholder syntax with spaces, and valid slug
    prepareIntroductionFiles(trackDir, "%{ concept : recursion }",
                             removeIntro = true)

    test "`configlet generate` exits with 0 for valid placeholder usage with spaces":
      const expectedOutput = fmt"""
        Outdated: {"exercises"/"concept"/"bird-count"/".docs"/"introduction.md"}
        Generated 1 file
      """.unindent().replace("\p", "\n")
      execAndCheck(0, generateCmdUpdateYes, expectedOutput)

    test "and writes the `introduction.md` file as expected":
      checkNoDiff(trackDir)

main()
{.used.}
