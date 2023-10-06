import std/[osproc, strformat, strutils, unittest]
import "."/[binary_helpers]

proc main =
  suite "help as an argument":
    test "help":
      let (outp, exitCode) = execCmdEx(&"{binaryPath} help")
      check:
        outp.contains(usageStart)
        exitCode == 0

  suite "help as an option":
    for goodHelp in ["-h", "--help"]:
      test goodHelp:
        let (outp, exitCode) = execCmdEx(&"{binaryPath} {goodHelp}")
        check:
          outp.contains(usageStart)
          exitCode == 0

  suite "help via normalization":
    for goodHelp in ["-H", "--HELP", "--hElP", "--HeLp", "--H--e-L__p"]:
      test goodHelp:
        let (outp, exitCode) = execCmdEx(&"{binaryPath} {goodHelp}")
        check:
          outp.contains(usageStart)
          exitCode == 0

  suite "help is always printed if present":
    for goodHelp in ["--help --update", "sync -uh", "-hu", "-ho", "sync -oh"]:
      test goodHelp:
        let (outp, exitCode) = execCmdEx(&"{binaryPath} {goodHelp}")
        check:
          outp.contains(usageStart)
          exitCode == 0

main()
{.used.}
