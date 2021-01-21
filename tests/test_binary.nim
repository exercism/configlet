import std/[os, osproc, strformat, strscans, strutils, unittest]
import "."/[uuid/uuid]

const
  binaryExt =
    when defined(windows): ".exe"
    else: ""
  binaryName = "configlet" & binaryExt

proc main =
  const repoRootDir = currentSourcePath.parentDir().parentDir()
  let binaryPath = repoRootDir / binaryName
  const helpStart = &"Usage:\n  {binaryName} [global-options] <command> [command-options]"

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
    for goodHelp in ["--help --check", "sync -ch", "-hc", "-ho", "sync -oh"]:
      test goodHelp:
        let (outp, exitCode) = execCmdEx(&"{binaryPath} {goodHelp}")
        check:
          outp.startsWith(helpStart)
          exitCode == 0

  suite "invalid command":
    for badCommand in ["h", "halp", "-", "_", "__", "foo", "FOO", "f-o-o",
                       "f_o_o", "f--o"]:
      test badCommand:
        let (outp, exitCode) = execCmdEx(&"{binaryPath} {badCommand}")
        check:
          outp.contains(&"invalid command: '{badCommand}'")
          exitCode == 1

  suite "invalid argument: sync":
    for badArg in ["h", "halp", "-", "_", "__", "foo", "FOO", "f-o-o", "f_o_o",
                   "f--o"]:
      test badArg:
        let (outp, exitCode) = execCmdEx(&"{binaryPath} sync {badArg}")
        check:
          outp.contains(&"invalid argument for command 'sync': '{badArg}'")
          exitCode == 1

  suite "invalid option: global":
    for badOption in ["--halp", "--checkk"]:
      test badOption:
        let (outp, exitCode) = execCmdEx(&"{binaryPath} {badOption}")
        check:
          outp.contains(&"invalid option: '{badOption}'")
          exitCode == 1

  suite "invalid option: sync":
    for badOption in ["--halp", "--checkk"]:
      test badOption:
        let (outp, exitCode) = execCmdEx(&"{binaryPath} sync {badOption}")
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
          let (outp, exitCode) = execCmdEx(&"{binaryPath} sync {option}{sep}{badValue}")
          check:
            outp.contains(&"invalid value for '{option}': '{badValue}'")
            exitCode == 1

  suite "valid option given to wrong command":
    for (command, opt, val) in [("uuid", "-c", ""),
                                ("uuid", "--mode", "choose"),
                                ("sync", "-n", "10")]:
      test &"{command} {opt} {val}":
        let (outp, exitCode) = execCmdEx(&"{binaryPath} {command} {opt} {val}")
        check:
          outp.contains(&"invalid option for '{command}': '{opt}'")
          exitCode == 1

  suite "more than one command":
    for (command, badArg) in [("uuid", "sync"),
                              ("sync", "uuid")]:
      test &"{command} {badArg}":
        let (outp, exitCode) = execCmdEx(&"{binaryPath} {command} {badArg}")
        check:
          outp.contains(&"invalid argument for command '{command}': '{badArg}'")
          exitCode == 1
    for cmd in ["uuid -n5 sync",
                "uuid -n5 sync -c",
                "sync -c uuid",
                "sync -c -mc -o uuid -n5"]:
      test &"{cmd}":
        let (outp, exitCode) = execCmdEx(&"{binaryPath} {cmd}")
        check:
          outp.contains(&"invalid argument for command")
          exitCode == 1

  suite "version":
    test "--version":
      let (outp, exitCode) = execCmdEx(&"{binaryPath} --version")
      var major, minor, patch: int
      check:
        outp.scanf("v$i.$i.$i$s$.", major, minor, patch)
        exitCode == 0

  suite "offline":
    for offline in ["--offline", "-o"]:
      test &"requires --prob-specs-dir: {offline}":
        let (outp, exitCode) = execCmdEx(&"{binaryPath} sync {offline}")
        check:
          outp.contains("'-o, --offline' was given without passing '-p, --prob-specs-dir'")
          exitCode == 1

  suite "uuid":
    for cmd in ["uuid", "uuid -n 100", &"uuid -vq -n {repeat('9', 50)}"]:
      test &"{cmd}":
        let (outp, exitCode) = execCmdEx(&"{binaryPath} {cmd}")
        check exitCode == 0
        for line in outp.strip.splitLines:
          check line.isValidUuidV4

main()
{.used.}
