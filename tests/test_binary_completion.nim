import std/[os, osproc, strformat, strutils, unittest]
import "."/[binary_helpers]

proc main =
  suite "completion":
    const completionsDir = repoRootDir / "completions"
    for shell in ["bash", "fish", "zsh"]:
      test shell:
        let c = shell[0]
        # Convert platform-specific line endings (e.g. CR+LF on Windows) to LF
        # before comparing. The below `replace` makes the tests pass on Windows.
        let expected = readFile(completionsDir / &"configlet.{shell}").replace("\p", "\n")
        execAndCheck(0, &"{binaryPath} completion --shell {shell}", expected)
        execAndCheck(0, &"{binaryPath} completion --shell {c}", expected)
        execAndCheck(0, &"{binaryPath} completion -s {shell}", expected)
        execAndCheck(0, &"{binaryPath} completion -s {c}", expected)
        execAndCheck(0, &"{binaryPath} completion -s{c}", expected)
    for shell in ["powershell"]:
      test &"{shell} (produces an error)":
        let (outp, exitCode) = execCmdEx(&"{binaryPath} completion -s {shell}")
        check:
          outp.contains(&"invalid value for '-s': '{shell}'")
          exitCode == 1
    test "the -s option is required":
      let (outp, exitCode) = execCmdEx(&"{binaryPath} completion")
      check:
        outp.contains(&"Please choose a shell. For example: `configlet completion -s bash`")
        exitCode == 1

main()
{.used.}
