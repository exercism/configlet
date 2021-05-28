import std/[os, osproc, strformat, strscans, strutils, unittest]
import "."/lint/validators

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
        execCmdEx(&"git -C {trackDir} checkout 6e909c9e5338cd567c20224069df00e031fb2efa")

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
-# This is an auto-generated file. Regular comments will be removed when this
-# file is regenerated. Regenerating will not touch any manually added keys,
-# so comments can be added in a "comment" key.
-
+# This is an auto-generated file.
+#
+# Regenerating this file will:
+# - Update the `description` property
+# - Update the `reimplements` property
+# - Remove `include = true` properties
+# - Preserve any other properties
+#
+# As regular comments will be removed when this file is regenerated, comments
+# can be added in a "comment" key.
+[0d25f8d7-4897-4338-a033-2d3d7a9af688]
+description = "can calculate public key when given a different private key"
+
--- exercises/practice/grade-school/.meta/tests.toml
+++ exercises/practice/grade-school/.meta/tests.toml
-# This is an auto-generated file. Regular comments will be removed when this
-# file is regenerated. Regenerating will not touch any manually added keys,
-# so comments can be added in a "comment" key.
-
+# This is an auto-generated file.
+#
+# Regenerating this file will:
+# - Update the `description` property
+# - Update the `reimplements` property
+# - Remove `include = true` properties
+# - Preserve any other properties
+#
+# As regular comments will be removed when this file is regenerated, comments
+# can be added in a "comment" key.
+[c125dab7-2a53-492f-a99a-56ad511940d8]
+description = "A student can't be in two different grades"
+
--- exercises/practice/hamming/.meta/tests.toml
+++ exercises/practice/hamming/.meta/tests.toml
-# This is an auto-generated file. Regular comments will be removed when this
-# file is regenerated. Regenerating will not touch any manually added keys,
-# so comments can be added in a "comment" key.
-
+# This is an auto-generated file.
+#
+# Regenerating this file will:
+# - Update the `description` property
+# - Update the `reimplements` property
+# - Remove `include = true` properties
+# - Preserve any other properties
+#
+# As regular comments will be removed when this file is regenerated, comments
+# can be added in a "comment" key.
+[db92e77e-7c72-499d-8fe6-9354d2bfd504]
+description = "disallow left empty strand"
+reimplements = "5dce058b-28d4-4ca7-aa64-adfe4e17784c"
+
+
+[920cd6e3-18f4-4143-b6b8-74270bb8f8a3]
+description = "disallow right empty strand"
+reimplements = "38826d4b-16fb-4639-ac3e-ba027dec8b5f"
--- exercises/practice/high-scores/.meta/tests.toml
+++ exercises/practice/high-scores/.meta/tests.toml
-# This is an auto-generated file. Regular comments will be removed when this
-# file is regenerated. Regenerating will not touch any manually added keys,
-# so comments can be added in a "comment" key.
-
+# This is an auto-generated file.
+#
+# Regenerating this file will:
+# - Update the `description` property
+# - Update the `reimplements` property
+# - Remove `include = true` properties
+# - Preserve any other properties
+#
+# As regular comments will be removed when this file is regenerated, comments
+# can be added in a "comment" key.
+
+[2df075f9-fec9-4756-8f40-98c52a11504f]
+description = "Latest score after personal top scores"
+
+[809c4058-7eb1-4206-b01e-79238b9b71bc]
+description = "Scores after personal top scores"
--- exercises/practice/kindergarten-garden/.meta/tests.toml
+++ exercises/practice/kindergarten-garden/.meta/tests.toml
-# This is an auto-generated file. Regular comments will be removed when this
-# file is regenerated. Regenerating will not touch any manually added keys,
-# so comments can be added in a "comment" key.
-
+# This is an auto-generated file.
+#
+# Regenerating this file will:
+# - Update the `description` property
+# - Update the `reimplements` property
+# - Remove `include = true` properties
+# - Preserve any other properties
+#
+# As regular comments will be removed when this file is regenerated, comments
+# can be added in a "comment" key.
-description = "first student's garden"
+description = "for Alice, first student's garden"
-description = "second student's garden"
+description = "for Bob, second student's garden"
+
+[566b621b-f18e-4c5f-873e-be30544b838c]
+description = "for Charlie"
+
+[3ad3df57-dd98-46fc-9269-1877abf612aa]
+description = "for David"
+
+[0f0a55d1-9710-46ed-a0eb-399ba8c72db2]
+description = "for Eve"
+
+[a7e80c90-b140-4ea1-aee3-f4625365c9a4]
+description = "for Fred"
+
+[9d94b273-2933-471b-86e8-dba68694c615]
+description = "for Ginny"
+
+[f55bc6c2-ade8-4844-87c4-87196f1b7258]
+description = "for Harriet"
+
+[759070a3-1bb1-4dd4-be2c-7cce1d7679ae]
+description = "for Ileana"
+
+[78578123-2755-4d4a-9c7d-e985b8dda1c6]
+description = "for Joseph"
-description = "second to last student's garden"
+description = "for Kincaid, second to last student's garden"
-description = "last student's garden"
+description = "for Larry, last student's garden"
--- exercises/practice/prime-factors/.meta/tests.toml
+++ exercises/practice/prime-factors/.meta/tests.toml
-# This is an auto-generated file. Regular comments will be removed when this
-# file is regenerated. Regenerating will not touch any manually added keys,
-# so comments can be added in a "comment" key.
-
+# This is an auto-generated file.
+#
+# Regenerating this file will:
+# - Update the `description` property
+# - Update the `reimplements` property
+# - Remove `include = true` properties
+# - Preserve any other properties
+#
+# As regular comments will be removed when this file is regenerated, comments
+# can be added in a "comment" key.
+[238d57c8-4c12-42ef-af34-ae4929f94789]
+description = "another prime number"
+
+[756949d3-3158-4e3d-91f2-c4f9f043ee70]
+description = "product of first prime"
+
+[7d6a3300-a4cb-4065-bd33-0ced1de6cb44]
+description = "product of second prime"
+
+[073ac0b2-c915-4362-929d-fc45f7b9a9e4]
+description = "product of third prime"
+
+[6e0e4912-7fb6-47f3-a9ad-dbcd79340c75]
+description = "product of first and second prime"
+
--- exercises/practice/react/.meta/tests.toml
+++ exercises/practice/react/.meta/tests.toml
-# This is an auto-generated file. Regular comments will be removed when this
-# file is regenerated. Regenerating will not touch any manually added keys,
-# so comments can be added in a "comment" key.
+# This is an auto-generated file.
+#
+# Regenerating this file will:
+# - Update the `description` property
+# - Update the `reimplements` property
+# - Remove `include = true` properties
+# - Preserve any other properties
+#
+# As regular comments will be removed when this file is regenerated, comments
+# can be added in a "comment" key.
+[c51ee736-d001-4f30-88d1-0c8e8b43cd07]
+description = "input cells have a value"
+
+[dedf0fe0-da0c-4d5d-a582-ffaf5f4d0851]
+description = "an input cell's value can be set"
+
+[5854b975-f545-4f93-8968-cc324cde746e]
+description = "compute cells calculate initial value"
+
+[25795a3d-b86c-4e91-abe7-1c340e71560c]
+description = "compute cells take inputs in the right order"
+
+[c62689bf-7be5-41bb-b9f8-65178ef3e8ba]
+description = "compute cells update value when dependencies are changed"
+
+[5ff36b09-0a88-48d4-b7f8-69dcf3feea40]
+description = "compute cells can depend on other compute cells"
+
+[abe33eaf-68ad-42a5-b728-05519ca88d2d]
+description = "compute cells fire callbacks"
+
+[9e5cb3a4-78e5-4290-80f8-a78612c52db2]
+description = "callback cells only fire on change"
+
+[ada17cb6-7332-448a-b934-e3d7495c13d3]
+description = "callbacks do not report already reported values"
+
+[ac271900-ea5c-461c-9add-eeebcb8c03e5]
+description = "callbacks can fire from multiple cells"
+
+[95a82dcc-8280-4de3-a4cd-4f19a84e3d6f]
+description = "callbacks can be added and removed"
+
+[f2a7b445-f783-4e0e-8393-469ab4915f2a]
+description = "removing a callback multiple times doesn't interfere with other callbacks"
+
+[daf6feca-09e0-4ce5-801d-770ddfe1c268]
+description = "callbacks should only be called once even if multiple dependencies change"
+
+[9a5b159f-b7aa-4729-807e-f1c38a46d377]
+description = "callbacks should not be called if dependencies change but output value doesn't change"
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

proc prepareIntroductionFiles(trackDir, header, placeholder: string;
                              removeIntro: bool) =
  # Writes an `introduction.md.tpl` file for the `bird-count` Concept Exercise,
  # containing the given `header` and `placeholder`. Also removes the
  # `introduction.md` file if `removeIntro` is `true`.
  let
    docsPath = trackDir / "exercises" / "concept" / "bird-count" / ".docs"
    introPath = docsPath / "introduction.md"
    templatePath = introPath & ".tpl"
    templateContents = fmt"""
      # {header}

      {placeholder}
    """.dedent()
  writeFile(templatePath, templateContents)
  if removeIntro:
    removeFile(introPath)

proc testsForGenerate(binaryPath: string) =
  suite "generate":
    const trackDir = ".test_binary_elixir_track_repo"
    let generateCmd = &"{binaryPath} -t {trackDir} generate"
    let diffCmd = &"git -C {trackDir} diff --exit-code"

    removeDir(trackDir)

    # Setup: clone a track repo
    block:
      execAndCheck(0):
        cloneExercismRepo("elixir", trackDir)

    # Setup: set the track repo to a known state
    block:
      execAndCheck(0):
        execCmdEx(&"git -C {trackDir} checkout f3974abf6e0d4a434dfe3494d58581d399c18edb")

    test "`configlet generate` exits with 0 when there are no `.md.tpl` files":
      execAndCheck(0):
        execCmdEx(generateCmd)

    test "and does not make a change":
      execAndCheck(0):
        execCmdEx(diffCmd)

    # Valid placeholder syntax without spaces, and invalid slug
    prepareIntroductionFiles(trackDir, "Recursion",
                             "%{concept:not-a-real-concept-slug}",
                             removeIntro = false)

    test "`configlet generate` exits with 1 for an invalid placeholder usage":
      execAndCheck(1):
        execCmdEx(generateCmd)

    test "and does not make a change":
      execAndCheck(0):
        execCmdEx(diffCmd)

    # Valid placeholder syntax without spaces, and valid slug
    prepareIntroductionFiles(trackDir, "Recursion", "%{concept:recursion}",
                             removeIntro = true)

    test "`configlet generate` exits with 0 for a valid `.md.tpl` file":
      execAndCheck(0):
        execCmdEx(generateCmd)

    test "and writes the `introduction.md` file as expected":
      execAndCheck(0):
        execCmdEx(diffCmd)

    # Valid placeholder syntax with spaces, and valid slug
    prepareIntroductionFiles(trackDir, "Recursion", "%{ concept : recursion }",
                             removeIntro = true)

    test "`configlet generate` exits with 0 for valid placeholder usage with spaces":
      execAndCheck(0):
        execCmdEx(generateCmd)

    test "and writes the `introduction.md` file as expected":
      execAndCheck(0):
        execCmdEx(diffCmd)

proc main =
  const repoRootDir = currentSourcePath.parentDir().parentDir()
  let binaryPath = repoRootDir / binaryName
  const helpStart = &"Usage:\n  {binaryName} [global-options] <command> [command-options]"

  const cmd = "nimble --verbose build -d:release"
  stderr.write(&"Running `{cmd}`... ")
  let (buildOutput, buildExitCode) = execCmdEx(cmd, workingDir = repoRootDir)
  if buildExitCode == 0:
    stderr.writeLine "success"
  else:
    stderr.writeLine "failure"
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
          check line.isUuidV4

  testsForSync(binaryPath)

  testsForGenerate(binaryPath)

main()
{.used.}
