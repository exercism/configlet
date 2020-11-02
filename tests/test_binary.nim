import std/[os, osproc, strformat, strscans, strutils, unittest]

const
  binaryExt =
    when defined(windows): ".exe"
    else: ""
  binaryName = "canonical_data_syncer" & binaryExt

proc main =
  let repoRootDir = getAppDir().parentDir()
  let binaryPath = repoRootDir / binaryName
  const helpStart = &"Usage: {binaryName} [options]"

  suite "help as an argument":
    test "help":
      let (outp, exitCode) = execCmdEx(&"{binaryPath} help")
      check:
        outp.startsWith(helpStart)
        exitCode == 0

  suite "help as an option":
    for goodHelp in ["-h", "--help"]:
      test goodHelp:
        let (outp, exitCode) = execCmdEx(&"{binaryPath} {goodHelp}")
        check:
          outp.startsWith(helpStart)
          exitCode == 0

  suite "help via normalization":
    for goodHelp in ["-H", "--HELP", "--hElP", "--HeLp", "--H--e-L__p"]:
      test goodHelp:
        let (outp, exitCode) = execCmdEx(&"{binaryPath} {goodHelp}")
        check:
          outp.startsWith(helpStart)
          exitCode == 0

  suite "help is always printed if present":
    for goodHelp in ["--help --check", "-ch", "-hc", "-ho", "-oh"]:
      test goodHelp:
        let (outp, exitCode) = execCmdEx(&"{binaryPath} {goodHelp}")
        check:
          outp.startsWith(helpStart)
          exitCode == 0

  suite "invalid argument":
    for badArg in ["h", "halp", "-", "_", "__", "foo", "FOO", "f-o-o", "f_o_o",
                   "f--o"]:
      test badArg:
        let (outp, exitCode) = execCmdEx(&"{binaryPath} {badArg}")
        check:
          outp.contains(&"invalid argument: '{badArg}'")
          exitCode == 1

  suite "invalid option":
    for badOption in ["--halp", "--checkk"]:
      test badOption:
        let (outp, exitCode) = execCmdEx(&"{binaryPath} {badOption}")
        check:
          outp.contains(&"invalid option: '{badOption}'")
          exitCode == 1

  suite "invalid value":
    for (option, badValue) in [("--mode", "foo"), ("--mode", "f"),
                               ("-m", "foo"), ("-m", "f"),
                               ("-m", "--check"), ("-m", "-c"),
                               ("-m", "-mc"), ("-m", "--mode")]:
      for sep in [" ", "=", ":"]:
        test &"{option}{sep}{badValue}":
          let (outp, exitCode) = execCmdEx(&"{binaryPath} {option}{sep}{badValue}")
          check:
            outp.contains(&"invalid value for '{option}': '{badValue}'")
            exitCode == 1

  suite "version":
    test "--version":
      let (outp, exitCode) = execCmdEx(&"{binaryPath} --version")
      var major, minor, patch: int
      check:
        outp.scanf("Canonical Data Syncer v$i.$i.$i$s$.", major, minor, patch)
        exitCode == 0

  suite "offline":
    for offline in ["--offline", "-o"]:
      test &"requires --prob-specs-dir: {offline}":
        let (outp, exitCode) = execCmdEx(&"{binaryPath} {offline}")
        check:
          outp.contains("'-o, --offline' was given without passing '-p, --prob-specs-dir'")
          exitCode == 1

main()
{.used.}
