import std/[os, osproc, strformat, strscans, strutils, unittest]
import "."/[uuid/uuid]

const
  binaryExt =
    when defined(windows): ".exe"
    else: ""
  binaryName = "configlet" & binaryExt

proc cloneExercismRepo(repoName, dest: string; isShallow = false): tuple[
    output: string; exitCode: int] =
  # Clones the Exercism repo named `repoName` to the location `dest`.
  let opts = if isShallow: "--depth 1" else: ""
  let url = &"https://github.com/exercism/{repoName}/"
  let cmd = &"git clone {opts} {url} {dest}"
  result = execCmdEx(cmd)

template execAndCheck(expectedExitCode: int; body: untyped) {.dirty.} =
  ## Runs `body`, and prints the output if the exit code is non-zero.
  ## `body` must have the same return type as `execCmdEx`.
  let (outp, exitCode) = body
  if exitCode != expectedExitCode:
    echo outp
    fail()

func conciseDiff(s: string): string =
  ## Returns the lines of `s` that begin with a `+` or `-` character.
  result = newStringOfCap(s.len)
  for line in s.splitLines():
    if line.len > 0:
      if line[0] in {'+', '-'}:
        result.add line
        result.add '\n'

proc testsForSync(binaryPath: string) =
  suite "sync":
    const psDir = ".test_binary_problem_specifications"
    const trackDir = ".test_binary_nim_track_repo"
    removeDir(psDir)
    removeDir(trackDir)

    # Setup: clone the problem-specifications repo
    block:
      execAndCheck(0):
        cloneExercismRepo("problem-specifications", psDir)

    # Setup: clone a track repo
    block:
      execAndCheck(0):
        cloneExercismRepo("nim", trackDir)

    # Setup: set the problem-specifications repo to a known state
    block:
      execAndCheck(0):
        execCmdEx(&"git -C {psDir} checkout ef9e1e17c84721ee6e9d5a65c8dd3ba2122eac91")

    # Setup: set the track repo to a known state
    block:
      execAndCheck(0):
        execCmdEx(&"git -C {trackDir} checkout 798a250a5baf44468ff39bf016fafc3c6a5375c2")

    test "`sync --check` exits with 1 and prints the expected output":
      execAndCheck(1):
        execCmdEx(&"{binaryPath} -t {trackDir} sync -co -p {psDir}")

      check outp == """
Checking exercises...
[warn] diffie-hellman: missing 1 test cases
       - can calculate public key when given a different private key (0d25f8d7-4897-4338-a033-2d3d7a9af688)
[warn] grade-school: missing 1 test cases
       - A student can't be in two different grades (c125dab7-2a53-492f-a99a-56ad511940d8)
[warn] hamming: missing 2 test cases
       - disallow left empty strand (db92e77e-7c72-499d-8fe6-9354d2bfd504)
       - disallow right empty strand (920cd6e3-18f4-4143-b6b8-74270bb8f8a3)
[warn] high-scores: missing 2 test cases
       - Latest score after personal top scores (2df075f9-fec9-4756-8f40-98c52a11504f)
       - Scores after personal top scores (809c4058-7eb1-4206-b01e-79238b9b71bc)
[warn] kindergarten-garden: missing 8 test cases
       - for Charlie (566b621b-f18e-4c5f-873e-be30544b838c)
       - for David (3ad3df57-dd98-46fc-9269-1877abf612aa)
       - for Eve (0f0a55d1-9710-46ed-a0eb-399ba8c72db2)
       - for Fred (a7e80c90-b140-4ea1-aee3-f4625365c9a4)
       - for Ginny (9d94b273-2933-471b-86e8-dba68694c615)
       - for Harriet (f55bc6c2-ade8-4844-87c4-87196f1b7258)
       - for Ileana (759070a3-1bb1-4dd4-be2c-7cce1d7679ae)
       - for Joseph (78578123-2755-4d4a-9c7d-e985b8dda1c6)
[warn] prime-factors: missing 5 test cases
       - another prime number (238d57c8-4c12-42ef-af34-ae4929f94789)
       - product of first prime (756949d3-3158-4e3d-91f2-c4f9f043ee70)
       - product of second prime (7d6a3300-a4cb-4065-bd33-0ced1de6cb44)
       - product of third prime (073ac0b2-c915-4362-929d-fc45f7b9a9e4)
       - product of first and second prime (6e0e4912-7fb6-47f3-a9ad-dbcd79340c75)
[warn] react: missing 14 test cases
       - input cells have a value (c51ee736-d001-4f30-88d1-0c8e8b43cd07)
       - an input cell's value can be set (dedf0fe0-da0c-4d5d-a582-ffaf5f4d0851)
       - compute cells calculate initial value (5854b975-f545-4f93-8968-cc324cde746e)
       - compute cells take inputs in the right order (25795a3d-b86c-4e91-abe7-1c340e71560c)
       - compute cells update value when dependencies are changed (c62689bf-7be5-41bb-b9f8-65178ef3e8ba)
       - compute cells can depend on other compute cells (5ff36b09-0a88-48d4-b7f8-69dcf3feea40)
       - compute cells fire callbacks (abe33eaf-68ad-42a5-b728-05519ca88d2d)
       - callback cells only fire on change (9e5cb3a4-78e5-4290-80f8-a78612c52db2)
       - callbacks do not report already reported values (ada17cb6-7332-448a-b934-e3d7495c13d3)
       - callbacks can fire from multiple cells (ac271900-ea5c-461c-9add-eeebcb8c03e5)
       - callbacks can be added and removed (95a82dcc-8280-4de3-a4cd-4f19a84e3d6f)
       - removing a callback multiple times doesn't interfere with other callbacks (f2a7b445-f783-4e0e-8393-469ab4915f2a)
       - callbacks should only be called once even if multiple dependencies change (daf6feca-09e0-4ce5-801d-770ddfe1c268)
       - callbacks should not be called if dependencies change but output value doesn't change (9a5b159f-b7aa-4729-807e-f1c38a46d377)
[warn] some exercises are missing test cases
"""

    test "`sync --mode=include` exits with 0 and includes the expected test cases":
      execAndCheck(0):
        execCmdEx(&"{binaryPath} -t {trackDir} sync -mi -o -p {psDir}")

      check outp == """
Syncing exercises...
[info] diffie-hellman: included 1 missing test cases
[info] grade-school: included 1 missing test cases
[info] hamming: included 2 missing test cases
[info] high-scores: included 2 missing test cases
[info] kindergarten-garden: included 8 missing test cases
[info] prime-factors: included 5 missing test cases
[info] react: included 14 missing test cases
All exercises are synced!
"""

    const expectedDiffOutput = """
--- exercises/practice/diffie-hellman/.meta/tests.toml
+++ exercises/practice/diffie-hellman/.meta/tests.toml
+# can calculate public key when given a different private key
+"0d25f8d7-4897-4338-a033-2d3d7a9af688" = true
+
--- exercises/practice/grade-school/.meta/tests.toml
+++ exercises/practice/grade-school/.meta/tests.toml
+# A student can't be in two different grades
+"c125dab7-2a53-492f-a99a-56ad511940d8" = true
+
--- exercises/practice/hamming/.meta/tests.toml
+++ exercises/practice/hamming/.meta/tests.toml
+# disallow left empty strand
+"db92e77e-7c72-499d-8fe6-9354d2bfd504" = true
+
+
+# disallow right empty strand
+"920cd6e3-18f4-4143-b6b8-74270bb8f8a3" = true
--- exercises/practice/high-scores/.meta/tests.toml
+++ exercises/practice/high-scores/.meta/tests.toml
+
+# Latest score after personal top scores
+"2df075f9-fec9-4756-8f40-98c52a11504f" = true
+
+# Scores after personal top scores
+"809c4058-7eb1-4206-b01e-79238b9b71bc" = true
--- exercises/practice/kindergarten-garden/.meta/tests.toml
+++ exercises/practice/kindergarten-garden/.meta/tests.toml
-# first student's garden
+# for Alice, first student's garden
-# second student's garden
+# for Bob, second student's garden
-# second to last student's garden
+# for Charlie
+"566b621b-f18e-4c5f-873e-be30544b838c" = true
+
+# for David
+"3ad3df57-dd98-46fc-9269-1877abf612aa" = true
+
+# for Eve
+"0f0a55d1-9710-46ed-a0eb-399ba8c72db2" = true
+
+# for Fred
+"a7e80c90-b140-4ea1-aee3-f4625365c9a4" = true
+
+# for Ginny
+"9d94b273-2933-471b-86e8-dba68694c615" = true
+
+# for Harriet
+"f55bc6c2-ade8-4844-87c4-87196f1b7258" = true
+
+# for Ileana
+"759070a3-1bb1-4dd4-be2c-7cce1d7679ae" = true
+
+# for Joseph
+"78578123-2755-4d4a-9c7d-e985b8dda1c6" = true
+
+# for Kincaid, second to last student's garden
-# last student's garden
+# for Larry, last student's garden
--- exercises/practice/prime-factors/.meta/tests.toml
+++ exercises/practice/prime-factors/.meta/tests.toml
+# another prime number
+"238d57c8-4c12-42ef-af34-ae4929f94789" = true
+
+# product of first prime
+"756949d3-3158-4e3d-91f2-c4f9f043ee70" = true
+
+# product of second prime
+"7d6a3300-a4cb-4065-bd33-0ced1de6cb44" = true
+
+# product of third prime
+"073ac0b2-c915-4362-929d-fc45f7b9a9e4" = true
+
+# product of first and second prime
+"6e0e4912-7fb6-47f3-a9ad-dbcd79340c75" = true
+
--- exercises/practice/react/.meta/tests.toml
+++ exercises/practice/react/.meta/tests.toml
-# "c51ee736-d001-4f30-88d1-0c8e8b43cd07" = true
+"c51ee736-d001-4f30-88d1-0c8e8b43cd07" = true
-# "dedf0fe0-da0c-4d5d-a582-ffaf5f4d0851" = true
+"dedf0fe0-da0c-4d5d-a582-ffaf5f4d0851" = true
-# "5854b975-f545-4f93-8968-cc324cde746e" = true
+"5854b975-f545-4f93-8968-cc324cde746e" = true
-# "25795a3d-b86c-4e91-abe7-1c340e71560c" = true
+"25795a3d-b86c-4e91-abe7-1c340e71560c" = true
-# "c62689bf-7be5-41bb-b9f8-65178ef3e8ba" = true
+"c62689bf-7be5-41bb-b9f8-65178ef3e8ba" = true
-# "5ff36b09-0a88-48d4-b7f8-69dcf3feea40" = true
+"5ff36b09-0a88-48d4-b7f8-69dcf3feea40" = true
-# "abe33eaf-68ad-42a5-b728-05519ca88d2d" = true
+"abe33eaf-68ad-42a5-b728-05519ca88d2d" = true
-# "9e5cb3a4-78e5-4290-80f8-a78612c52db2" = true
+"9e5cb3a4-78e5-4290-80f8-a78612c52db2" = true
-# "ada17cb6-7332-448a-b934-e3d7495c13d3" = true
+"ada17cb6-7332-448a-b934-e3d7495c13d3" = true
-# "ac271900-ea5c-461c-9add-eeebcb8c03e5" = true
+"ac271900-ea5c-461c-9add-eeebcb8c03e5" = true
-# "95a82dcc-8280-4de3-a4cd-4f19a84e3d6f" = true
+"95a82dcc-8280-4de3-a4cd-4f19a84e3d6f" = true
-# "f2a7b445-f783-4e0e-8393-469ab4915f2a" = true
+"f2a7b445-f783-4e0e-8393-469ab4915f2a" = true
-# "daf6feca-09e0-4ce5-801d-770ddfe1c268" = true
+"daf6feca-09e0-4ce5-801d-770ddfe1c268" = true
-# "9a5b159f-b7aa-4729-807e-f1c38a46d377" = true
+"9a5b159f-b7aa-4729-807e-f1c38a46d377" = true
"""

    const diffOpts = "--no-ext-diff --text --unified=0 --no-prefix --color=never"
    const diffCmd = &"""git --no-pager -C {trackDir} diff {diffOpts}"""
    test "`git diff` shows the expected diff":
      execAndCheck(0):
        execCmdEx(diffCmd)

      check outp.conciseDiff() == expectedDiffOutput

    test "after syncing, another `sync --mode=include` performs no changes":
      execAndCheck(0):
        execCmdEx(&"{binaryPath} -t {trackDir} sync -mi -o -p {psDir}")

      check outp == """
Syncing exercises...
All exercises are synced!
"""

    test "after syncing, `sync --check` shows that exercises are up to date":
      execAndCheck(0):
        execCmdEx(&"{binaryPath} -t {trackDir} sync -c -o -p {psDir}")
      check outp == """
Checking exercises...
All exercises are up-to-date!
"""

    test "the `git diff` output is still the same":
      execAndCheck(0):
        execCmdEx(diffCmd)

      check outp.conciseDiff() == expectedDiffOutput

proc main =
  const repoRootDir = currentSourcePath.parentDir().parentDir()
  let binaryPath = repoRootDir / binaryName
  const helpStart = &"Usage:\n  {binaryName} [global-options] <command> [command-options]"

  const cmd = "nimble --verbose build -d:release"
  stdout.write(&"Running `{cmd}`... ")
  stdout.flushFile()
  let (buildOutput, buildExitCode) = execCmdEx(cmd, workingDir = repoRootDir)
  if buildExitCode == 0:
    echo "success"
  else:
    echo "failure"
    raise newException(OSError, buildOutput)

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
        outp.scanf("$i.$i.$i", major, minor, patch)
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

  testsForSync(binaryPath)

main()
{.used.}
