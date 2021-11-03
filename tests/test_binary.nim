import std/[os, osproc, strformat, strscans, strutils, unittest]
import "."/[exec, lint/validators]

const
  testsDir = currentSourcePath().parentDir()
  repoRootDir = testsDir.parentDir()

template execAndCheckExitCode(expectedExitCode: int; cmd: string;
                              inputStr = "") =
  ## Runs `cmd`, supplying `inputStr` on stdin, and checks that its exit code is
  ## `expectedExitCode`
  let exitCode = execCmdEx(cmd, input = inputStr)[1]
  check:
    exitCode == expectedExitCode

template execAndCheck(expectedExitCode: int; cmd, expectedOutput: string;
                      inputStr = "") =
  ## Runs `cmd`, supplying `inputStr` on stdin, and checks that:
  ## - its exit code is `expectedExitCode`
  ## - its output is `expectedOutput`
  let (outp, exitCode) = execCmdEx(cmd, input = inputStr)
  check:
    exitCode == expectedExitCode
    outp == expectedOutput

template testDiffThenRestore(dir, expectedDiff, restoreArg: string) =
  ## Runs `git diff` in `dir`, and tests that the output is `expectedDiff`. Then
  ## runs `git restore` with the argument `restoreArg`.
  test "the diff is as expected":
    let diff = gitDiffConcise(trackDir)
    check diff == expectedDiff

  let args = ["-C", dir, "restore", restoreArg]
  check git(args).exitCode == 0

proc testsForSync(binaryPath: static string) =
  const psDir = testsDir / ".test_problem_specifications"
  const trackDir = testsDir / ".test_nim_track_repo"

  # Setup: clone the problem-specifications repo, and checkout a known state
  setupExercismRepo("problem-specifications", psDir,
                    "daf620d47ed905409564dec5fa9610664e294bde") # 2021-06-18

  # Setup: clone a track repo, and checkout a known state
  setupExercismRepo("nim", trackDir,
                    "736245965db724cafc5ec8e9dcae83c850b7c5a8") # 2021-10-22

  const
    syncOffline = &"{binaryPath} -t {trackDir} sync -o -p {psDir}"
    syncOfflineUpdate = &"{syncOffline} --update"
    syncOfflineUpdateTests = &"{syncOfflineUpdate} --tests"

    header = "Checking exercises..."
    headerUpdateTests = "Updating tests..."
    footerUnsyncedDocs = "[warn] some exercises have unsynced docs"
    # footerUnsyncedFilepaths = "[warn] some exercises have unsynced filepaths"
    footerUnsyncedMetadata = "[warn] some exercises have unsynced metadata"
    footerUnsyncedTests = "[warn] some exercises are missing test cases"
    footerSyncedFilepaths = """
      Every Practice Exercise has up-to-date filepaths!""".unindent()
    footerSyncedTests = """
      Every Practice Exercise has up-to-date tests!""".unindent()
    bodyUnsyncedDocs = """
      [warn] hamming: instructions.md is unsynced
      [warn] yacht: instructions.md is unsynced""".unindent()
    bodyUnsyncedMetadata = """
      [warn] acronym: metadata are unsynced
      [warn] armstrong-numbers: metadata are unsynced
      [warn] binary: metadata are unsynced
      [warn] collatz-conjecture: metadata are unsynced
      [warn] darts: metadata are unsynced
      [warn] grade-school: metadata are unsynced
      [warn] hello-world: metadata are unsynced
      [warn] high-scores: metadata are unsynced
      [warn] resistor-color: metadata are unsynced
      [warn] reverse-string: metadata are unsynced
      [warn] scale-generator: metadata are unsynced
      [warn] twelve-days: metadata are unsynced
      [warn] two-fer: metadata are unsynced
      [warn] yacht: metadata are unsynced""".unindent()
    bodyUnsyncedTests = """
      [warn] anagram: missing 1 test case
             - detects two anagrams (03eb9bbe-8906-4ea0-84fa-ffe711b52c8b)
      [warn] diffie-hellman: missing 1 test case
             - can calculate public key when given a different private key (0d25f8d7-4897-4338-a033-2d3d7a9af688)
      [warn] grade-school: missing 1 test case
             - A student can't be in two different grades (c125dab7-2a53-492f-a99a-56ad511940d8)
      [warn] hamming: missing 6 test cases
             - disallow first strand longer (b9228bb1-465f-4141-b40f-1f99812de5a8)
             - disallow second strand longer (dab38838-26bb-4fff-acbe-3b0a9bfeba2d)
             - disallow left empty strand (db92e77e-7c72-499d-8fe6-9354d2bfd504)
             - disallow empty first strand (b764d47c-83ff-4de2-ab10-6cfe4b15c0f3)
             - disallow right empty strand (920cd6e3-18f4-4143-b6b8-74270bb8f8a3)
             - disallow empty second strand (9ab9262f-3521-4191-81f5-0ed184a5aa89)
      [warn] high-scores: missing 2 test cases
             - Top 3 scores -> Latest score after personal top scores (2df075f9-fec9-4756-8f40-98c52a11504f)
             - Top 3 scores -> Scores after personal top scores (809c4058-7eb1-4206-b01e-79238b9b71bc)
      [warn] isogram: missing 1 test case
             - word with duplicated character and with two hyphens (0d0b8644-0a1e-4a31-a432-2b3ee270d847)
      [warn] kindergarten-garden: missing 8 test cases
             - full garden -> for Charlie (566b621b-f18e-4c5f-873e-be30544b838c)
             - full garden -> for David (3ad3df57-dd98-46fc-9269-1877abf612aa)
             - full garden -> for Eve (0f0a55d1-9710-46ed-a0eb-399ba8c72db2)
             - full garden -> for Fred (a7e80c90-b140-4ea1-aee3-f4625365c9a4)
             - full garden -> for Ginny (9d94b273-2933-471b-86e8-dba68694c615)
             - full garden -> for Harriet (f55bc6c2-ade8-4844-87c4-87196f1b7258)
             - full garden -> for Ileana (759070a3-1bb1-4dd4-be2c-7cce1d7679ae)
             - full garden -> for Joseph (78578123-2755-4d4a-9c7d-e985b8dda1c6)
      [warn] luhn: missing 1 test case
             - non-numeric, non-space char in the middle with a sum that's divisible by 10 isn't allowed (8b72ad26-c8be-49a2-b99c-bcc3bf631b33)
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
             - callbacks should not be called if dependencies change but output value doesn't change (9a5b159f-b7aa-4729-807e-f1c38a46d377)""".dedent(6)
    # Note: `dedent` above, not `unindent`. We want to preserve the indentation of the list items.

  suite "sync, without --update":
    # With synced items
    test "--docs: with synced docs, prints the expected output, and exits with 0":
      const expectedOutput = fmt"""
        {header}
        The `bob` Practice Exercise has up-to-date docs!
      """.unindent()
      execAndCheck(0, &"{syncOffline} -e bob --docs", expectedOutput)

    test "--filepaths: with synced filepaths, prints the expected output, and exits with 0":
      const expectedOutput = fmt"""
        {header}
        The `bob` Practice Exercise has up-to-date filepaths!
      """.unindent()
      execAndCheck(0, &"{syncOffline} -e bob --filepaths", expectedOutput)

    test "--metadata: with synced metadata, prints the expected output, and exits with 0":
      const expectedOutput = fmt"""
        {header}
        The `bob` Practice Exercise has up-to-date metadata!
      """.unindent()
      execAndCheck(0, &"{syncOffline} -e bob --metadata", expectedOutput)

    test "--tests: with synced tests, prints the expected output, and exits with 0":
      const expectedOutput = fmt"""
        {header}
        The `bob` Practice Exercise has up-to-date tests!
      """.unindent()
      execAndCheck(0, &"{syncOffline} -e bob --tests", expectedOutput)

    test "--metadata --tests: with synced metadata and tests, prints the expected output, and exits with 0":
      const expectedOutput = fmt"""
        {header}
        The `bob` Practice Exercise has up-to-date metadata!
        The `bob` Practice Exercise has up-to-date tests!
      """.unindent()
      execAndCheck(0, &"{syncOffline} -e bob --metadata --tests", expectedOutput)

    test "no scope: with everything synced, prints the expected output, and exits with 0":
      const expectedOutput = fmt"""
        {header}
        The `bob` Practice Exercise has up-to-date docs, filepaths, metadata, and tests!
      """.unindent()
      execAndCheck(0, &"{syncOffline} -e bob", expectedOutput)

    test "--filepaths: with synced filepaths for every exercise, prints the expected output, and exits with 0":
      const expectedOutput = fmt"""
        {header}
        {footerSyncedFilepaths}
      """.unindent()
      execAndCheck(0, &"{syncOffline} --filepaths", expectedOutput)

    # With unsynced items
    test "--docs: with unsynced docs, prints the expected output, and exits with 1":
      const expectedOutput = fmt"""
        {header}
        {bodyUnsyncedDocs}
        {footerUnsyncedDocs}
      """.unindent()
      execAndCheck(1, &"{syncOffline} --docs", expectedOutput)

    test "--metadata: with unsynced metadata, prints the expected output, and exits with 1":
      const expectedOutput = fmt"""
        {header}
        {bodyUnsyncedMetadata}
        {footerUnsyncedMetadata}
      """.unindent()
      execAndCheck(1, &"{syncOffline} --metadata", expectedOutput)

    test "--tests: with unsynced tests, prints the expected output, and exits with 1":
      const expectedOutput = &"{header}\n{bodyUnsyncedTests}\n{footerUnsyncedTests}\n"
      execAndCheck(1, &"{syncOffline} --tests", expectedOutput)

    const docsMetadataTests = &"{header}\n" &
                              &"{bodyUnsyncedDocs}\n{bodyUnsyncedMetadata}\n{bodyUnsyncedTests}\n" &
                              &"{footerUnsyncedDocs}\n{footerUnsyncedMetadata}\n{footerUnsyncedTests}\n"

    test "--docs --metadata --tests: with unsynced docs + metadata + tests, prints the expected output, and exits with 1":
      execAndCheck(1, &"{syncOffline} --docs --metadata --tests", docsMetadataTests)

    test "no scope: multiple exercises with unsynced docs + metadata + tests, prints the expected output, and exits with 1":
      execAndCheck(1, syncOffline, docsMetadataTests)

    test "no scope: a given exercise with only tests unsynced: prints the expected output, and exits with 1":
      const expectedOutput = fmt"""
        {header}
        [warn] anagram: missing 1 test case
               - detects two anagrams (03eb9bbe-8906-4ea0-84fa-ffe711b52c8b)
        {footerUnsyncedTests}
      """.dedent(8)
      execAndCheck(1, &"{syncOffline} -e anagram", expectedOutput)

    test "no scope: when passing multiple exercises, only the final exercise is acted upon":
      # TODO: configlet should either print a warning here, or support multiple exercises being passed.
      const expectedOutput = fmt"""
        {header}
        [warn] isogram: missing 1 test case
               - word with duplicated character and with two hyphens (0d0b8644-0a1e-4a31-a432-2b3ee270d847)
        {footerUnsyncedTests}
      """.dedent(8)
      execAndCheck(1, &"{syncOffline} -e grade-school -e isogram", expectedOutput)

  suite "sync, with --update":
    const
      expectedOutputAnagramInclude = fmt"""
        {header}
        {headerUpdateTests}
        [info] anagram: included 1 missing test case
        The `anagram` Practice Exercise has up-to-date tests!
      """.unindent()

      expectedOutputAnagramExclude = fmt"""
        {header}
        {headerUpdateTests}
        [info] anagram: excluded 1 missing test case
        The `anagram` Practice Exercise has up-to-date tests!
      """.unindent()

      testsTomlHeaderDiff = """
        -# This is an auto-generated file. Regular comments will be removed when this
        -# file is regenerated. Regenerating will not touch any manually added keys,
        -# so comments can be added in a "comment" key.
        +# This is an auto-generated file.
        +#
        +# Regenerating this file via `configlet sync` will:
        +# - Recreate every `description` key/value pair
        +# - Recreate every `reimplements` key/value pair, where they exist in problem-specifications
        +# - Remove any `include = true` key/value pair (an omitted `include` key implies inclusion)
        +# - Preserve any other key/value pair
        +#
        +# As user-added comments (using the # character) will be removed when this file
        +# is regenerated, comments can be added via a `comment` key.""".unindent()

      expectedAnagramDiffStart = fmt"""
        --- exercises/practice/anagram/.meta/tests.toml
        +++ exercises/practice/anagram/.meta/tests.toml
        {testsTomlHeaderDiff}""".unindent()

      expectedAnagramDiffInclude = fmt"""
        {expectedAnagramDiffStart}
        +[03eb9bbe-8906-4ea0-84fa-ffe711b52c8b]
        +description = "detects two anagrams"
        +reimplements = "b3cca662-f50a-489e-ae10-ab8290a09bdc"
        +
      """.unindent()

      expectedAnagramDiffChooseInclude = fmt"""
        {expectedAnagramDiffStart}
        +include = false
        +
        +[03eb9bbe-8906-4ea0-84fa-ffe711b52c8b]
        +description = "detects two anagrams"
        +reimplements = "b3cca662-f50a-489e-ae10-ab8290a09bdc"
      """.unindent()

      expectedAnagramDiffExclude = fmt"""
        {expectedAnagramDiffStart}
        +[03eb9bbe-8906-4ea0-84fa-ffe711b52c8b]
        +description = "detects two anagrams"
        +include = false
        +reimplements = "b3cca662-f50a-489e-ae10-ab8290a09bdc"
        +
      """.unindent()

    let anagramTestsTomlPath = joinPath("exercises", "practice", "anagram",
                                        ".meta", "tests.toml")

    test "-mi: includes a missing test case for a given exercise, and exits with 0":
      execAndCheck(0, &"{syncOfflineUpdateTests} -e anagram -mi", expectedOutputAnagramInclude)
    testDiffThenRestore(trackDir, expectedAnagramDiffInclude, anagramTestsTomlPath)

    test "-me: excludes a missing test case for a given exercise, and exits with 0":
      execAndCheck(0, &"{syncOfflineUpdateTests} -e anagram -me", expectedOutputAnagramExclude)
    testDiffThenRestore(trackDir, expectedAnagramDiffExclude, anagramTestsTomlPath)

    test "-mc: includes a missing test case for a given exercise when the input is 'y', and exits with 0":
      execAndCheckExitCode(0, &"{syncOfflineUpdateTests} -e anagram -mc", inputStr = "y")
    testDiffThenRestore(trackDir, expectedAnagramDiffChooseInclude, anagramTestsTomlPath)

    test "-mc: excludes a missing test case for a given exercise when the input is 'n', and exits with 0":
      execAndCheckExitCode(0, &"{syncOfflineUpdateTests} -e anagram -mc", inputStr = "n")
    testDiffThenRestore(trackDir, expectedAnagramDiffExclude, anagramTestsTomlPath)

    test "-mc: neither includes nor excludes a missing test case for a given exercise when the input is 's', and exits with 1":
      execAndCheckExitCode(1, &"{syncOfflineUpdateTests} -e anagram -mc", inputStr = "s")
    testDiffThenRestore(trackDir, expectedAnagramDiffStart & "\n", anagramTestsTomlPath)

    test "-mi: includes every missing test case when not specifying an exercise, and exits with 0":
      const expectedOutput = fmt"""
        {header}
        {headerUpdateTests}
        [info] anagram: included 1 missing test case
        [info] diffie-hellman: included 1 missing test case
        [info] grade-school: included 1 missing test case
        [info] hamming: included 6 missing test cases
        [info] high-scores: included 2 missing test cases
        [info] isogram: included 1 missing test case
        [info] kindergarten-garden: included 8 missing test cases
        [info] luhn: included 1 missing test case
        [info] prime-factors: included 5 missing test cases
        [info] react: included 14 missing test cases
        {footerSyncedTests}
      """.unindent()
      execAndCheck(0, &"{syncOfflineUpdateTests} -mi", expectedOutput)

    const expectedDiffOutput = fmt"""
      --- exercises/practice/anagram/.meta/tests.toml
      +++ exercises/practice/anagram/.meta/tests.toml
      {testsTomlHeaderDiff}
      +[03eb9bbe-8906-4ea0-84fa-ffe711b52c8b]
      +description = "detects two anagrams"
      +reimplements = "b3cca662-f50a-489e-ae10-ab8290a09bdc"
      +
      --- exercises/practice/diffie-hellman/.meta/tests.toml
      +++ exercises/practice/diffie-hellman/.meta/tests.toml
      {testsTomlHeaderDiff}
      +[0d25f8d7-4897-4338-a033-2d3d7a9af688]
      +description = "can calculate public key when given a different private key"
      +
      --- exercises/practice/grade-school/.meta/tests.toml
      +++ exercises/practice/grade-school/.meta/tests.toml
      {testsTomlHeaderDiff}
      +[c125dab7-2a53-492f-a99a-56ad511940d8]
      +description = "A student can't be in two different grades"
      +
      --- exercises/practice/hamming/.meta/tests.toml
      +++ exercises/practice/hamming/.meta/tests.toml
      {testsTomlHeaderDiff}
      +[b9228bb1-465f-4141-b40f-1f99812de5a8]
      +description = "disallow first strand longer"
      +reimplements = "919f8ef0-b767-4d1b-8516-6379d07fcb28"
      +
      +[dab38838-26bb-4fff-acbe-3b0a9bfeba2d]
      +description = "disallow second strand longer"
      +reimplements = "8a2d4ed0-ead5-4fdd-924d-27c4cf56e60e"
      +
      +[db92e77e-7c72-499d-8fe6-9354d2bfd504]
      +description = "disallow left empty strand"
      +reimplements = "5dce058b-28d4-4ca7-aa64-adfe4e17784c"
      +
      +[b764d47c-83ff-4de2-ab10-6cfe4b15c0f3]
      +description = "disallow empty first strand"
      +reimplements = "db92e77e-7c72-499d-8fe6-9354d2bfd504"
      +
      +
      +[920cd6e3-18f4-4143-b6b8-74270bb8f8a3]
      +description = "disallow right empty strand"
      +reimplements = "38826d4b-16fb-4639-ac3e-ba027dec8b5f"
      +
      +[9ab9262f-3521-4191-81f5-0ed184a5aa89]
      +description = "disallow empty second strand"
      +reimplements = "920cd6e3-18f4-4143-b6b8-74270bb8f8a3"
      --- exercises/practice/high-scores/.meta/tests.toml
      +++ exercises/practice/high-scores/.meta/tests.toml
      {testsTomlHeaderDiff}
      -description = "Personal top three from a list of scores"
      +description = "Top 3 scores -> Personal top three from a list of scores"
      -description = "Personal top highest to lowest"
      +description = "Top 3 scores -> Personal top highest to lowest"
      -description = "Personal top when there is a tie"
      +description = "Top 3 scores -> Personal top when there is a tie"
      -description = "Personal top when there are less than 3"
      +description = "Top 3 scores -> Personal top when there are less than 3"
      -description = "Personal top when there is only one"
      +description = "Top 3 scores -> Personal top when there is only one"
      +
      +[2df075f9-fec9-4756-8f40-98c52a11504f]
      +description = "Top 3 scores -> Latest score after personal top scores"
      +
      +[809c4058-7eb1-4206-b01e-79238b9b71bc]
      +description = "Top 3 scores -> Scores after personal top scores"
      --- exercises/practice/isogram/.meta/tests.toml
      +++ exercises/practice/isogram/.meta/tests.toml
      {testsTomlHeaderDiff}
      +
      +[0d0b8644-0a1e-4a31-a432-2b3ee270d847]
      +description = "word with duplicated character and with two hyphens"
      --- exercises/practice/kindergarten-garden/.meta/tests.toml
      +++ exercises/practice/kindergarten-garden/.meta/tests.toml
      {testsTomlHeaderDiff}
      -description = "garden with single student"
      +description = "partial garden -> garden with single student"
      -description = "different garden with single student"
      +description = "partial garden -> different garden with single student"
      -description = "garden with two students"
      +description = "partial garden -> garden with two students"
      -description = "second student's garden"
      +description = "partial garden -> multiple students for the same garden with three students -> second student's garden"
      -description = "third student's garden"
      +description = "partial garden -> multiple students for the same garden with three students -> third student's garden"
      -description = "first student's garden"
      +description = "full garden -> for Alice, first student's garden"
      -description = "second student's garden"
      +description = "full garden -> for Bob, second student's garden"
      +
      +[566b621b-f18e-4c5f-873e-be30544b838c]
      +description = "full garden -> for Charlie"
      +
      +[3ad3df57-dd98-46fc-9269-1877abf612aa]
      +description = "full garden -> for David"
      +
      +[0f0a55d1-9710-46ed-a0eb-399ba8c72db2]
      +description = "full garden -> for Eve"
      +
      +[a7e80c90-b140-4ea1-aee3-f4625365c9a4]
      +description = "full garden -> for Fred"
      +
      +[9d94b273-2933-471b-86e8-dba68694c615]
      +description = "full garden -> for Ginny"
      +
      +[f55bc6c2-ade8-4844-87c4-87196f1b7258]
      +description = "full garden -> for Harriet"
      +
      +[759070a3-1bb1-4dd4-be2c-7cce1d7679ae]
      +description = "full garden -> for Ileana"
      +
      +[78578123-2755-4d4a-9c7d-e985b8dda1c6]
      +description = "full garden -> for Joseph"
      -description = "second to last student's garden"
      +description = "full garden -> for Kincaid, second to last student's garden"
      -description = "last student's garden"
      +description = "full garden -> for Larry, last student's garden"
      --- exercises/practice/luhn/.meta/tests.toml
      +++ exercises/practice/luhn/.meta/tests.toml
      {testsTomlHeaderDiff}
      +
      +[8b72ad26-c8be-49a2-b99c-bcc3bf631b33]
      +description = "non-numeric, non-space char in the middle with a sum that's divisible by 10 isn't allowed"
      --- exercises/practice/prime-factors/.meta/tests.toml
      +++ exercises/practice/prime-factors/.meta/tests.toml
      {testsTomlHeaderDiff}
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
      {testsTomlHeaderDiff}
      +
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
    """.unindent()

    test "the diff is as expected":
      let diff = gitDiffConcise(trackDir)
      check diff == expectedDiffOutput

    test "after updating tests, another tests update using -mi performs no changes, and exits with 0":
      const expectedOutput = fmt"""
        {header}
        {headerUpdateTests}
        {footerSyncedTests}
      """.unindent()
      execAndCheck(0, &"{syncOfflineUpdateTests} -mi", expectedOutput)

    test "after updating only tests, a plain `sync` shows that only docs are unsynced, and exits with 1":
      const expectedOutput = fmt"""
        {header}
        {bodyUnsyncedDocs}
        {bodyUnsyncedMetadata}
        {footerUnsyncedDocs}
        {footerUnsyncedMetadata}
      """.unindent()
      execAndCheck(1, syncOffline, expectedOutput)

    test "the diff is still the same":
      let diff = gitDiffConcise(trackDir)
      check diff == expectedDiffOutput

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
    """.unindent()
  writeFile(templatePath, templateContents)
  if removeIntro:
    removeFile(introPath)

template checkNoDiff(trackDir: string) =
  check gitDiffExitCode(trackDir) == 0

proc testsForGenerate(binaryPath: string) =
  suite "generate":
    const trackDir = testsDir / ".test_elixir_track_repo"
    let generateCmd = &"{binaryPath} -t {trackDir} generate"

    # Setup: clone a track repo, and checkout a known state
    setupExercismRepo("elixir", trackDir,
                      "f3974abf6e0d4a434dfe3494d58581d399c18edb") # 2021-05-09

    test "`configlet generate` exits with 0 when there are no `.md.tpl` files":
      execAndCheck(0, generateCmd, "")

    test "and does not make a change":
      checkNoDiff(trackDir)

    # Valid placeholder syntax without spaces, and invalid slug
    prepareIntroductionFiles(trackDir, "Recursion",
                             "%{concept:not-a-real-concept-slug}",
                             removeIntro = false)

    test "`configlet generate` exits with 1 for an invalid placeholder usage":
      execAndCheckExitCode(1, generateCmd)

    test "and does not make a change":
      checkNoDiff(trackDir)

    # Valid placeholder syntax without spaces, and valid slug
    prepareIntroductionFiles(trackDir, "Recursion", "%{concept:recursion}",
                             removeIntro = true)

    test "`configlet generate` exits with 0 for a valid `.md.tpl` file":
      execAndCheck(0, generateCmd, "")

    test "and writes the `introduction.md` file as expected":
      checkNoDiff(trackDir)

    # Valid placeholder syntax with spaces, and valid slug
    prepareIntroductionFiles(trackDir, "Recursion", "%{ concept : recursion }",
                             removeIntro = true)

    test "`configlet generate` exits with 0 for valid placeholder usage with spaces":
      execAndCheck(0, generateCmd, "")

    test "and writes the `introduction.md` file as expected":
      checkNoDiff(trackDir)

proc main =
  const
    binaryExt =
      when defined(windows): ".exe"
      else: ""
    binaryName = &"configlet{binaryExt}"
    binaryPath = repoRootDir / binaryName
    helpStart = &"Usage:\n  {binaryName} [global-options] <command> [command-options]"

  if not defined(skipBuild):
    let args =
      if existsEnv("CI"):
        @["--verbose", "build", "-d:release"]
      else:
        @["--verbose", "build"]
    discard execAndCheck(0, "nimble", args, workingDir = repoRootDir,
                         verbose = true)

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
    for goodHelp in ["--help --update", "sync -uh", "-hu", "-ho", "sync -oh"]:
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
    for (option, badValue) in [("--mode", "foo"), ("--mode", "f"),
                               ("-m", "foo"), ("-m", "f"),
                               ("-m", "--update"), ("-m", "-u"),
                               ("-m", "-mc"), ("-m", "--mode")]:
      for sep in [" ", "=", ":"]:
        test &"{option}{sep}{badValue}":
          let (outp, exitCode) = execCmdEx(&"{binaryPath} sync {option}{sep}{badValue}")
          check:
            outp.contains(&"invalid value for '{option}': '{badValue}'")
            exitCode == 1

  suite "valid option given to wrong command":
    for (command, opt, val) in [("uuid", "-u", ""),
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
                "uuid -n5 sync -u",
                "sync -u uuid",
                "sync -u -mc -o uuid -n5"]:
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
