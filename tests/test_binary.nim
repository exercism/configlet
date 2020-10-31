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
      let (outp, _) = execCmdEx(&"{binaryPath} help")
      check:
        outp.startsWith(helpStart)

  suite "help as an option":
    for goodHelp in ["-h", "--help"]:
      test goodHelp:
        let (outp, _) = execCmdEx(&"{binaryPath} {goodHelp}")
        check:
          outp.startsWith(helpStart)

  suite "help via normalization":
    for goodHelp in ["-H", "--HELP", "--hElP", "--HeLp", "--H--e-L__p"]:
      test goodHelp:
        let (outp, _) = execCmdEx(&"{binaryPath} {goodHelp}")
        check:
          outp.startsWith(helpStart)

  suite "help is always printed if present":
    for goodHelp in ["--help --check", "-ch", "-hc", "-ho", "-oh"]:
      test goodHelp:
        let (outp, _) = execCmdEx(&"{binaryPath} {goodHelp}")
        check:
          outp.startsWith(helpStart)

  suite "invalid argument":
    for badArg in ["h", "halp", "-", "_", "__", "foo", "FOO", "f-o-o", "f_o_o",
                   "f--o"]:
      test badArg:
        let (outp, _) = execCmdEx(&"{binaryPath} {badArg}")
        check:
          outp.contains(&"invalid argument: '{badArg}'")

  suite "invalid option":
    for badOption in ["--halp", "--checkk"]:
      test badOption:
        let (outp, _) = execCmdEx(&"{binaryPath} {badOption}")
        check:
          outp.contains(&"invalid option: '{badOption}'")

  suite "invalid value":
    for (option, badValue) in [("--mode", "foo"), ("--mode", "f"),
                               ("-m", "foo"), ("-m", "f"),
                               ("-m", "--check"), ("-m", "-c"),
                               ("-m", "-mc"), ("-m", "--mode")]:
      for sep in [" ", "=", ":"]:
        test &"{option}{sep}{badValue}":
          let (outp, _) = execCmdEx(&"{binaryPath} {option}{sep}{badValue}")
          check:
            outp.contains(&"invalid value for '{option}': '{badValue}'")

  suite "version":
    test "--version":
      let (outp, _) = execCmdEx(&"{binaryPath} --version")
      var major, minor, patch: int
      check:
        outp.scanf("Canonical Data Syncer v$i.$i.$i$s$.", major, minor, patch)

  suite "offline":
    for offline in ["--offline", "-o"]:
      test &"requires --prob-specs-dir: {offline}":
        let (outp, _) = execCmdEx(&"{binaryPath} {offline}")
        check:
          outp.contains("'-o, --offline' was given without passing '-p, --prob-specs-dir'")

main()
{.used.}
