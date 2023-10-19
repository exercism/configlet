import std/[os, osproc, strformat, strscans, strutils, unittest]
import exec, helpers, lint/validators, sync/probspecs
import "."/[binary_helpers]

proc main =
  if not defined(skipBuild):
    let args =
      if existsEnv("CI"):
        @["--verbose", "build", "-d:release"]
      else:
        @["--verbose", "build"]
    discard execAndCheck(0, "nimble", args, workingDir = repoRootDir,
                         verbose = true)

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
    for badOption in ["--halp", "--updatee"]:
      test badOption:
        let (outp, exitCode) = execCmdEx(&"{binaryPath} {badOption}")
        check:
          outp.contains(&"invalid option: '{badOption}'")
          exitCode == 1

  suite "invalid option: sync":
    for badOption in ["--halp", "--updatee"]:
      test badOption:
        let (outp, exitCode) = execCmdEx(&"{binaryPath} sync {badOption}")
        check:
          outp.contains(&"invalid option: '{badOption}'")
          exitCode == 1

  suite "invalid value":
    for (option, badValue) in [("--verbosity", "foo"), ("--verbosity", "f"),
                               ("-v", "foo"), ("-v", "f"),
                               ("-v", "--update"), ("-v", "-u"),
                               ("-v", "-t=foo"), ("-v", "--verbosity")]:
      for sep in [" ", "=", ":"]:
        test &"{option}{sep}{badValue}":
          let (outp, exitCode) = execCmdEx(&"{binaryPath} sync {option}{sep}{badValue}")
          check:
            outp.contains(&"invalid value for '{option}': '{badValue}'")
            exitCode == 1

  suite "valid option given to wrong command":
    for (command, opt, val) in [("uuid", "-u", ""),
                                ("uuid", "--tests", "choose"),
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
                "uuid -n5 sync -u",
                "sync -u uuid",
                "sync -u -o uuid -n5"]:
      test &"{cmd}":
        let (outp, exitCode) = execCmdEx(&"{binaryPath} {cmd}")
        check:
          outp.contains(&"invalid argument for command")
          exitCode == 1

  when not defined(windows): # Ignore differences due to ".exe" and line endings.
    suite "README":
      test "README contains usage message":
        let (outp, _) = execCmdEx(&"{binaryPath} --help")
        let readmeContents = readFile(repoRootDir / "README.md")
        let usage = outp[outp.find("Usage")..^1]
        check:
          usage in readmeContents

main()
{.used.}
