import std/[os, osproc, strformat, strscans, strutils, unittest]
import exec, helpers, lint/validators, sync/probspecs

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

template gitRestore(dir, arg: string) =
  let args = ["-C", dir, "restore", arg]
  check git(args).exitCode == 0

template testDiffThenRestore(dir, expectedDiff, restoreArg: string) =
  ## Runs `git diff` in `dir`, and tests that the output is `expectedDiff`. Then
  ## runs `git restore` with the argument `restoreArg`.
  test "the diff is as expected":
    let diff = gitDiffConcise(trackDir)
    check diff == expectedDiff
  gitRestore(dir, restoreArg)

template checkNoDiff(trackDir: string) =
  check gitDiffExitCode(trackDir) == 0

proc testsForSync(binaryPath: static string) =
  const psDir = getCacheDir() / "exercism" / "configlet" / "problem-specifications"
  const trackDir = testsDir / ".test_nim_track_repo"

  # Setup: clone the problem-specifications repo, and checkout a known state
  setupExercismRepo("problem-specifications", psDir,
                    "daf620d47ed905409564dec5fa9610664e294bde") # 2021-06-18

  # Setup: clone a track repo, and checkout a known state
  setupExercismRepo("nim", trackDir,
                    "736245965db724cafc5ec8e9dcae83c850b7c5a8") # 2021-10-22

  const
    syncBase = &"{binaryPath} -t {trackDir} sync"
    syncOffline = &"{syncBase} -o"
    syncOfflineUpdate = &"{syncOffline} --update"
    syncOfflineUpdateTests = &"{syncOfflineUpdate} --tests"

    header = "Checking exercises..."
    footerUnsyncedDocs = "[warn] some exercises have unsynced docs"
    # footerUnsyncedFilepaths = "[warn] some exercises have unsynced filepaths"
    footerUnsyncedMetadata = "[warn] some exercises have unsynced metadata"
    footerUnsyncedTests = "[warn] some exercises are missing test cases"
    footerSyncedFilepaths = """
      Every exercise has up-to-date filepaths!""".unindent()
    footerSyncedMetadata = """
      Every exercise has up-to-date metadata!""".unindent()
    footerSyncedTests = """
      Every exercise has up-to-date tests!""".unindent()
    bodyUnsyncedDocs = """
      [warn] docs: instructions unsynced: hamming
      [warn] docs: instructions unsynced: yacht""".unindent()
    bodyUnsyncedMetadata = """
      [warn] metadata: unsynced: acronym
      [warn] metadata: unsynced: armstrong-numbers
      [warn] metadata: unsynced: collatz-conjecture
      [warn] metadata: unsynced: darts
      [warn] metadata: unsynced: grade-school
      [warn] metadata: unsynced: hello-world
      [warn] metadata: unsynced: high-scores
      [warn] metadata: unsynced: resistor-color
      [warn] metadata: unsynced: reverse-string
      [warn] metadata: unsynced: scale-generator
      [warn] metadata: unsynced: twelve-days
      [warn] metadata: unsynced: two-fer
      [warn] metadata: unsynced: yacht""".unindent()
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

  suite "sync, when the track `config.json` file is not found (prints the expected output, and exits with 1)":
    test "-t foo":
      const expectedOutput = fmt"""
        Error: cannot open: my_missing_directory{DirSep}config.json
      """.unindent()
      let cmd = &"{binaryPath} -t my_missing_directory sync -o"
      execAndCheck(1, cmd, expectedOutput)

  suite "sync, for an exercise that does not exist (prints the expected output, and exits with 1)":
    test "-e foo":
      const expectedOutput = fmt"""
        The `-e, --exercise` option was used to specify an exercise slug, but `foo` is not an slug in the track config:
        {trackDir / "config.json"}
      """.unindent()
      execAndCheck(1, &"{syncOffline} -e foo --docs", expectedOutput)

  suite "sync, without --update, checking parseopt3 patch (--tests -e bob is parsed correctly)":
    # With an unpatched cligen/parseopt3, we can only write `--tests` without a
    # value if we write it at the end of the command line. For example, running
    #     $ configlet sync --tests -e bob
    # would produce
    #     Error: invalid value for '--tests': '-e'
    # This is because:
    # - parseopt3 knows which options can take a value, and supports a value
    #   starting with the `-` character. That is, it does not naively just
    #   assume that every parameter starting with `-` is an option.
    # - The `--tests` option is special amongst our options. It can take a value
    #   of `choose|include|exclude`, because a separate `--tests-mode` option
    #   seems overly verbose. But it makes sense for just `--tests` alone to
    #   work, and do the same as `--tests choose`, because `--docs`,
    #   `--filepaths` and `--metadata` all work (these options do not take a
    #   value).
    # As a workaround, we patch `parseopt3.nim` so that given a long option
    # followed by a space and a parameter that begins with the `-` character,
    # that parameter is always parsed as an option, not a value.
    test "--tests -e bob":
      const expectedOutput = fmt"""
        {header}
        The `bob` exercise has up-to-date tests!
      """.unindent()
      execAndCheck(0, &"{syncOffline} --tests -e bob", expectedOutput)

  suite "sync, without --update, for an up-to-date exercise (prints the expected output, and exits with 0)":
    test "-e bob --docs":
      const expectedOutput = fmt"""
        {header}
        The `bob` exercise has up-to-date docs!
      """.unindent()
      execAndCheck(0, &"{syncOffline} -e bob --docs", expectedOutput)

    test "-e bob --filepaths":
      const expectedOutput = fmt"""
        {header}
        The `bob` exercise has up-to-date filepaths!
      """.unindent()
      execAndCheck(0, &"{syncOffline} -e bob --filepaths", expectedOutput)

    test "-e bob --metadata":
      const expectedOutput = fmt"""
        {header}
        The `bob` exercise has up-to-date metadata!
      """.unindent()
      execAndCheck(0, &"{syncOffline} -e bob --metadata", expectedOutput)

    test "-e bob --tests":
      const expectedOutput = fmt"""
        {header}
        The `bob` exercise has up-to-date tests!
      """.unindent()
      execAndCheck(0, &"{syncOffline} -e bob --tests", expectedOutput)

    test "-e bob --metadata --tests":
      const expectedOutput = fmt"""
        {header}
        The `bob` exercise has up-to-date metadata!
        The `bob` exercise has up-to-date tests!
      """.unindent()
      execAndCheck(0, &"{syncOffline} -e bob --metadata --tests", expectedOutput)

    test "-e bob":
      const expectedOutput = fmt"""
        {header}
        The `bob` exercise has up-to-date docs, filepaths, metadata, and tests!
      """.unindent()
      execAndCheck(0, &"{syncOffline} -e bob", expectedOutput)

  suite "sync, without --update, for an up-to-date scope with every exercise (prints the expected output, and exits with 0)":
    test "--filepaths":
      const expectedOutput = fmt"""
        {header}
        {footerSyncedFilepaths}
      """.unindent()
      execAndCheck(0, &"{syncOffline} --filepaths", expectedOutput)

  suite "sync, without --update, for an unsynced scope for one exercise (prints the expected output, and exits with 1)":
    test "-e yacht --docs":
      const expectedOutput = fmt"""
        {header}
        [warn] docs: instructions unsynced: yacht
        {footerUnsyncedDocs}
      """.unindent()
      execAndCheck(1, &"{syncOffline} -e yacht --docs", expectedOutput)

    test "-e darts --metadata":
      const expectedOutput = fmt"""
        {header}
        [warn] metadata: unsynced: darts
        {footerUnsyncedMetadata}
      """.unindent()
      execAndCheck(1, &"{syncOffline} -e darts --metadata", expectedOutput)

    test "-e isogram --tests":
      const expectedOutput = fmt"""
        {header}
        [warn] isogram: missing 1 test case
               - word with duplicated character and with two hyphens (0d0b8644-0a1e-4a31-a432-2b3ee270d847)
        {footerUnsyncedTests}
      """.dedent(8)
      execAndCheck(1, &"{syncOffline} -e isogram --tests", expectedOutput)

    test "-e grade-school -e isogram --tests (when passing multiple exercises, only the final exercise is acted upon)":
      # TODO: configlet should either print a warning here, or support multiple exercises being passed.
      const expectedOutput = fmt"""
        {header}
        [warn] isogram: missing 1 test case
               - word with duplicated character and with two hyphens (0d0b8644-0a1e-4a31-a432-2b3ee270d847)
        {footerUnsyncedTests}
      """.dedent(8)
      execAndCheck(1, &"{syncOffline} -e grade-school -e isogram --tests", expectedOutput)

    test "-e isogram":
      const expectedOutput = fmt"""
        {header}
        [warn] isogram: missing 1 test case
               - word with duplicated character and with two hyphens (0d0b8644-0a1e-4a31-a432-2b3ee270d847)
        {footerUnsyncedTests}
      """.dedent(8)
      execAndCheck(1, &"{syncOffline} -e isogram", expectedOutput)

  suite "sync, without --update, for multiple unsynced scopes for one exercise (prints the expected output, and exits with 1)":
    test "-e yacht --docs --metadata":
      const expectedOutput = fmt"""
        {header}
        [warn] docs: instructions unsynced: yacht
        [warn] metadata: unsynced: yacht
        {footerUnsyncedDocs}
        {footerUnsyncedMetadata}
      """.unindent()
      execAndCheck(1, &"{syncOffline} -e yacht --docs --metadata", expectedOutput)

    test "-e yacht":
      const expectedOutput = fmt"""
        {header}
        [warn] docs: instructions unsynced: yacht
        [warn] metadata: unsynced: yacht
        {footerUnsyncedDocs}
        {footerUnsyncedMetadata}
      """.unindent()
      execAndCheck(1, &"{syncOffline} -e yacht", expectedOutput)

  suite "sync, without --update, for an unsynced scope with every exercise (prints the expected output, and exits with 1)":
    test "--docs":
      const expectedOutput = fmt"""
        {header}
        {bodyUnsyncedDocs}
        {footerUnsyncedDocs}
      """.unindent()
      execAndCheck(1, &"{syncOffline} --docs", expectedOutput)

    test "--metadata":
      const expectedOutput = fmt"""
        {header}
        {bodyUnsyncedMetadata}
        {footerUnsyncedMetadata}
      """.unindent()
      execAndCheck(1, &"{syncOffline} --metadata", expectedOutput)

    test "--tests":
      const expectedOutput = &"{header}\n{bodyUnsyncedTests}\n{footerUnsyncedTests}\n"
      execAndCheck(1, &"{syncOffline} --tests", expectedOutput)

    const docsMetadataTests = &"{header}\n" &
                              &"{bodyUnsyncedDocs}\n{bodyUnsyncedMetadata}\n{bodyUnsyncedTests}\n" &
                              &"{footerUnsyncedDocs}\n{footerUnsyncedMetadata}\n{footerUnsyncedTests}\n"

    test "--docs --metadata --tests":
      execAndCheck(1, &"{syncOffline} --docs --metadata --tests", docsMetadataTests)

    test "no options":
      execAndCheck(1, syncOffline, docsMetadataTests)

  suite "sync, with --update and --metadata, without --yes (no diff for an exercise with up-to-date metadata, and exits with 1)":
    test "--metadata -e bob":
      let exitCode = execCmdEx(&"{syncOfflineUpdate} --metadata -e bob")[1]
      check exitCode == 1
      checkNoDiff(trackDir)

  suite "sync, with --update and --metadata (no diff for an exercise with up-to-date metadata, and exits with 0)":
    test "--metadata -e bob":
      const expectedOutput = fmt"""
        {header}
        The `bob` exercise has up-to-date metadata!
      """.unindent()
      execAndCheck(0, &"{syncOfflineUpdate} --metadata -e bob --yes", expectedOutput)
      checkNoDiff(trackDir)

  suite "sync, with --update and --metadata (adds metadata for exercise with missing/empty/unsynced `.meta/config.json`, and exits with 0)":
    const expectedDiff = """
      --- exercises/practice/diffie-hellman/.meta/config.json
      +++ exercises/practice/diffie-hellman/.meta/config.json
      -  "blurb": "Diffie-Hellman key exchange.",
      -  "authors": [
      -    "ee7"
      -  ],
      -  "contributors": [],
      +  "authors": [],
      -    "solution": [
      -      "diffie_hellman.nim"
      -    ],
      -    "test": [
      -      "test_diffie_hellman.nim"
      -    ],
      -    "example": [
      -      ".meta/example.nim"
      -    ]
      +    "solution": [],
      +    "test": [],
      +    "example": []
      +  "blurb": "Diffie-Hellman key exchange.",
    """.unindent()
    let configPath = joinPath("exercises", "practice", "diffie-hellman", ".meta", "config.json")
    let configPathAbsolute = trackDir / configPath
    let metaDir = configPathAbsolute.parentDir()
    doAssert metaDir.lastPathPart() == ".meta"

    test "--metadata --yes -e diffie-hellman (missing `.meta` dir)":
      const expectedOutput = fmt"""
        {header}
        [warn] metadata: missing .meta directory: diffie-hellman
        Updated the metadata for 1 Practice Exercise
        The `diffie-hellman` exercise has up-to-date metadata!
      """.unindent()
      removeDir(metaDir)
      execAndCheck(0, &"{syncOfflineUpdate} --metadata --yes -e diffie-hellman", expectedOutput)
    gitRestore(trackDir, configPath.parentDir() / "example.nim")
    gitRestore(trackDir, configPath.parentDir() / "tests.toml")
    testDiffThenRestore(trackDir, expectedDiff, configPath)

    test "--metadata --yes -e diffie-hellman (missing `.meta/config.json`)":
      const expectedOutput = fmt"""
        {header}
        [warn] metadata: missing .meta/config.json file: diffie-hellman
        Updated the metadata for 1 Practice Exercise
        The `diffie-hellman` exercise has up-to-date metadata!
      """.unindent()
      removeFile(configPathAbsolute)
      execAndCheck(0, &"{syncOfflineUpdate} --metadata --yes -e diffie-hellman", expectedOutput)
    testDiffThenRestore(trackDir, expectedDiff, configPath)

    const expectedOutput = fmt"""
      {header}
      [warn] metadata: unsynced: diffie-hellman
      Updated the metadata for 1 Practice Exercise
      The `diffie-hellman` exercise has up-to-date metadata!
    """.unindent()
    # The `blurb`, `source`, and `source_url` are added again.

    test "--metadata --yes -e diffie-hellman (`.meta/config.json` is zero-length)":
      removeFile(configPathAbsolute)
      writeFile(configPathAbsolute, "")
      execAndCheck(0, &"{syncOfflineUpdate} --metadata --yes -e diffie-hellman", expectedOutput)
    testDiffThenRestore(trackDir, expectedDiff, configPath)

    test "--metadata --yes -e diffie-hellman (`.meta/config.json` is empty JSON object)":
      removeFile(configPathAbsolute)
      writeFile(configPathAbsolute, "{}")
      execAndCheck(0, &"{syncOfflineUpdate} --metadata --yes -e diffie-hellman", expectedOutput)
    testDiffThenRestore(trackDir, expectedDiff, configPath)

    test "--metadata --yes -e diffie-hellman (empty `blurb` value)":
      removeFile(configPathAbsolute)
      writeFile(configPathAbsolute, """{"blurb": ""}""")
      execAndCheck(0, &"{syncOfflineUpdate} --metadata --yes -e diffie-hellman", expectedOutput)
    testDiffThenRestore(trackDir, expectedDiff, configPath)

    test "--metadata --yes -e diffie-hellman (empty `blurb`, `source`, `source_url` value)":
      removeFile(configPathAbsolute)
      writeFile(configPathAbsolute, """{"blurb": "", "source": "", "source_url": ""}""")
      execAndCheck(0, &"{syncOfflineUpdate} --metadata --yes -e diffie-hellman", expectedOutput)
    testDiffThenRestore(trackDir, expectedDiff, configPath)

  suite "sync, with --update and --metadata (updates unsynced metadata for a given exercise, and exits with 0)":
    const expectedOutput = fmt"""
      {header}
      [warn] metadata: unsynced: darts
      Updated the metadata for 1 Practice Exercise
      The `darts` exercise has up-to-date metadata!
    """.unindent()
    const expectedDiff = """
      --- exercises/practice/darts/.meta/config.json
      +++ exercises/practice/darts/.meta/config.json
      -  "blurb": "Write a function that returns the earned points in a single toss of a Darts game",
      +  "blurb": "Write a function that returns the earned points in a single toss of a Darts game.",
    """.unindent()
    let configPath = joinPath("exercises", "practice", "darts", ".meta", "config.json")

    test "--metadata --yes -e darts":
      execAndCheck(0, &"{syncOfflineUpdate} --metadata --yes -e darts", expectedOutput)
    testDiffThenRestore(trackDir, expectedDiff, configPath)

  suite "sync, with --update and --metadata (updates metadata for every exercise, and exits with 0)":
    const expectedOutput = fmt"""
      {header}
      {bodyUnsyncedMetadata}
      Updated the metadata for 13 Practice Exercises
      {footerSyncedMetadata}
    """.unindent()
    const expectedDiff = """
      --- exercises/practice/acronym/.meta/config.json
      +++ exercises/practice/acronym/.meta/config.json
      -  "blurb": "Convert a long phrase to its acronym",
      +  "blurb": "Convert a long phrase to its acronym.",
      --- exercises/practice/armstrong-numbers/.meta/config.json
      +++ exercises/practice/armstrong-numbers/.meta/config.json
      -  "blurb": "Determine if a number is an Armstrong number",
      +  "blurb": "Determine if a number is an Armstrong number.",
      --- exercises/practice/collatz-conjecture/.meta/config.json
      +++ exercises/practice/collatz-conjecture/.meta/config.json
      -  "blurb": "Calculate the number of steps to reach 1 using the Collatz conjecture",
      +  "blurb": "Calculate the number of steps to reach 1 using the Collatz conjecture.",
      --- exercises/practice/darts/.meta/config.json
      +++ exercises/practice/darts/.meta/config.json
      -  "blurb": "Write a function that returns the earned points in a single toss of a Darts game",
      +  "blurb": "Write a function that returns the earned points in a single toss of a Darts game.",
      --- exercises/practice/grade-school/.meta/config.json
      +++ exercises/practice/grade-school/.meta/config.json
      -  "blurb": "Given students' names along with the grade that they are in, create a roster for the school",
      +  "blurb": "Given students' names along with the grade that they are in, create a roster for the school.",
      --- exercises/practice/hello-world/.meta/config.json
      +++ exercises/practice/hello-world/.meta/config.json
      -  "blurb": "The classical introductory exercise. Just say \"Hello, World!\"",
      +  "blurb": "The classical introductory exercise. Just say \"Hello, World!\".",
      --- exercises/practice/high-scores/.meta/config.json
      +++ exercises/practice/high-scores/.meta/config.json
      -  "blurb": "Manage a player's High Score list",
      +  "blurb": "Manage a player's High Score list.",
      --- exercises/practice/resistor-color/.meta/config.json
      +++ exercises/practice/resistor-color/.meta/config.json
      -  "blurb": "Convert a resistor band's color to its numeric representation",
      +  "blurb": "Convert a resistor band's color to its numeric representation.",
      --- exercises/practice/reverse-string/.meta/config.json
      +++ exercises/practice/reverse-string/.meta/config.json
      -  "blurb": "Reverse a string",
      +  "blurb": "Reverse a string.",
      --- exercises/practice/scale-generator/.meta/config.json
      +++ exercises/practice/scale-generator/.meta/config.json
      -  "blurb": "Generate musical scales, given a starting note and a set of intervals. ",
      +  "blurb": "Generate musical scales, given a starting note and a set of intervals.",
      --- exercises/practice/twelve-days/.meta/config.json
      +++ exercises/practice/twelve-days/.meta/config.json
      -  "blurb": "Output the lyrics to 'The Twelve Days of Christmas'",
      +  "blurb": "Output the lyrics to 'The Twelve Days of Christmas'.",
      --- exercises/practice/two-fer/.meta/config.json
      +++ exercises/practice/two-fer/.meta/config.json
      -  "blurb": "Create a sentence of the form \"One for X, one for me.\"",
      +  "blurb": "Create a sentence of the form \"One for X, one for me.\".",
      --- exercises/practice/yacht/.meta/config.json
      +++ exercises/practice/yacht/.meta/config.json
      -  "blurb": "Score a single throw of dice in the game Yacht",
      +  "blurb": "Score a single throw of dice in the game Yacht.",
    """.unindent()
    let configPaths = joinPath("exercises", "practice", "*", ".meta", "config.json")

    test "--metadata --yes":
      execAndCheck(0, &"{syncOfflineUpdate} --metadata --yes", expectedOutput)
    testDiffThenRestore(trackDir, expectedDiff, configPaths)

  suite "sync, with --update and --tests":
    const expectedErrorUpdateChoose = """
      '-y, --yes' was provided to non-interactively update, but tests are in
      the syncing scope and the tests updating mode is 'choose'.

      You can either:
      - use '--tests include' or '--tests exclude' to non-interactively include/exclude
        missing tests
      - or narrow the syncing scope via some combination of '--docs', '--filepaths', and
        '--metadata' (removing '--tests' if it was passed)
      - or remove '-y, --yes', and update by answering prompts

      If no syncing scope option is provided, configlet uses the full syncing scope.
      If '--tests' is provided without an argument, configlet uses the 'choose' mode.
    """.dedent(6)

    for options in ["-y", "-y --docs", "-y --filepaths", "-y --metadata",
                    "choose -y", "choose -y --docs", "choose -y --filepaths",
                    "choose -y --metadata"]:
      test &"--tests {options}: prints an error message, and exits with 1":
        let (outp, exitCode) = execCmdEx(&"{syncOfflineUpdateTests} {options}")
        check:
          outp.contains(expectedErrorUpdateChoose)
          exitCode == 1
        checkNoDiff(trackDir)

    const expectedErrorUpdateChooseNonInteractive = """
      configlet ran in a non-interactive context, but interaction was required because
      '--update' was passed without '--yes', and at least one of docs, filepaths, and
      metadata were in the syncing scope.

      You can either:
      - keep using configlet non-interactively, and add the '--yes' option to perform
        changes without confirmation
      - or keep using configlet non-interactively, and remove the '--update' option so
        that configlet performs no changes
      - or run the same command in an interactive terminal, to update by answering
        prompts
    """.dedent(6)

    for options in ["", "--docs", "--filepaths", "--metadata", "--tests --docs",
                    "--tests --filepaths", "--tests --metadata",
                    "--docs --filepaths", "--docs --metadata",
                    "--docs --filepaths --metadata",
                    "--docs --filepaths --metadata --tests"]:
      test &"{options}: prints an error message, and exits with 1":
        let (outp, exitCode) = execCmdEx(&"{syncOfflineUpdate} {options}")
        check:
          outp.contains(expectedErrorUpdateChooseNonInteractive)
          exitCode == 1
        checkNoDiff(trackDir)

    const
      expectedOutputAnagramInclude = fmt"""
        {header}
        [info] anagram: included 1 missing test case
        The `anagram` exercise has up-to-date tests!
      """.unindent()

      expectedOutputAnagramExclude = fmt"""
        {header}
        [info] anagram: excluded 1 missing test case
        The `anagram` exercise has up-to-date tests!
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

    test "--tests include: includes a missing test case for a given exercise, and exits with 0":
      execAndCheck(0, &"{syncOfflineUpdateTests} include -e anagram", expectedOutputAnagramInclude)
    testDiffThenRestore(trackDir, expectedAnagramDiffInclude, anagramTestsTomlPath)

    test "--tests exclude: excludes a missing test case for a given exercise, and exits with 0":
      execAndCheck(0, &"{syncOfflineUpdateTests} exclude -e anagram", expectedOutputAnagramExclude)
    testDiffThenRestore(trackDir, expectedAnagramDiffExclude, anagramTestsTomlPath)

    test &"--tests include -y: includes a missing test case for a given exercise, and exits with 0":
      execAndCheck(0, &"{syncOfflineUpdateTests} include -e anagram -y", expectedOutputAnagramInclude)
    testDiffThenRestore(trackDir, expectedAnagramDiffInclude, anagramTestsTomlPath)

    test &"--tests exclude -y: excludes a missing test case for a given exercise, and exits with 0":
      execAndCheck(0, &"{syncOfflineUpdateTests} exclude -e anagram -y", expectedOutputAnagramExclude)
    testDiffThenRestore(trackDir, expectedAnagramDiffExclude, anagramTestsTomlPath)

    test "--tests choose: includes a missing test case for a given exercise when the input is 'y', and exits with 0":
      execAndCheckExitCode(0, &"{syncOfflineUpdateTests} choose -e anagram",
                           inputStr = "y")
    testDiffThenRestore(trackDir, expectedAnagramDiffInclude, anagramTestsTomlPath)

    test "--tests choose: excludes a missing test case for a given exercise when the input is 'n', and exits with 0":
      execAndCheckExitCode(0, &"{syncOfflineUpdateTests} choose -e anagram",
                           inputStr = "n")
    testDiffThenRestore(trackDir, expectedAnagramDiffExclude, anagramTestsTomlPath)

    test "--tests choose: neither includes nor excludes a missing test case for a given exercise when the input is 's', and exits with 1":
      execAndCheckExitCode(1, &"{syncOfflineUpdateTests} choose -e anagram",
                           inputStr = "s")
    testDiffThenRestore(trackDir, expectedAnagramDiffStart & "\n", anagramTestsTomlPath)

    test "--tests include: includes every missing test case when not specifying an exercise, and exits with 0":
      const expectedOutput = fmt"""
        {header}
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
      execAndCheck(0, &"{syncOfflineUpdateTests} include", expectedOutput)

    const expectedDiffOutput = fmt"""
      --- exercises/practice/anagram/.meta/tests.toml
      +++ exercises/practice/anagram/.meta/tests.toml
      {testsTomlHeaderDiff}
      +include = false
      +
      +[03eb9bbe-8906-4ea0-84fa-ffe711b52c8b]
      +description = "detects two anagrams"
      +reimplements = "b3cca662-f50a-489e-ae10-ab8290a09bdc"
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
      +include = false
      +
      +[b9228bb1-465f-4141-b40f-1f99812de5a8]
      +description = "disallow first strand longer"
      +reimplements = "919f8ef0-b767-4d1b-8516-6379d07fcb28"
      +include = false
      +
      +[dab38838-26bb-4fff-acbe-3b0a9bfeba2d]
      +description = "disallow second strand longer"
      +reimplements = "8a2d4ed0-ead5-4fdd-924d-27c4cf56e60e"
      +include = false
      +
      +[db92e77e-7c72-499d-8fe6-9354d2bfd504]
      +description = "disallow left empty strand"
      +include = false
      +reimplements = "5dce058b-28d4-4ca7-aa64-adfe4e17784c"
      +
      +[b764d47c-83ff-4de2-ab10-6cfe4b15c0f3]
      +description = "disallow empty first strand"
      +reimplements = "db92e77e-7c72-499d-8fe6-9354d2bfd504"
      +include = false
      +
      +[920cd6e3-18f4-4143-b6b8-74270bb8f8a3]
      +description = "disallow right empty strand"
      +include = false
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

    test "after updating tests, another tests update using --tests include performs no changes, and exits with 0":
      const expectedOutput = fmt"""
        {header}
        {footerSyncedTests}
      """.unindent()
      execAndCheck(0, &"{syncOfflineUpdateTests} include", expectedOutput)

    test "after updating only tests, a plain `sync` shows that only docs and metadata are unsynced, and exits with 1":
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

  # Don't leave cached prob-specs dir in detached HEAD state.
  check git(["-C", psDir, "checkout", "main"]).exitCode == 0

  suite "sync, without --offline":
    test "can pull changes into cached prob-specs":
      # Reset local `main` to a previous commit.
      check git(["-C", psDir, "reset", "--hard",
                 "0eda2318cb5622532e498559255c8fe141c9d07f"]).exitCode == 0

      # Perform a sync without `--offline`.
      execAndCheckExitCode(1, syncBase)

      # Check that local HEAD and `main` point to same commit as the upstream `main`.
      const mainBranchName = "main"
      const upstreamHost = "github.com"
      const upstreamLocation = "exercism/problem-specifications"
      let probSpecsDir = ProbSpecsDir(psDir) # Don't use `init` (it performs extra setup).
      let remoteName = getNameOfRemote(probSpecsDir, upstreamHost, upstreamLocation)
      withDir psDir:
        let upstreamLatestRef = gitCheck(0, ["rev-parse", &"{remoteName}/{mainBranchName}"])
        let localHead = gitCheck(0, ["rev-parse", "HEAD"])
        let localMain = gitCheck(0, ["rev-parse", mainBranchName])
        check:
          upstreamLatestRef == localHead
          upstreamLatestRef == localMain

        # Return the local `main` to previous state, even if the sync failed
        # (for example, due to no network connection).
        discard gitCheck(0, ["merge", "--ff-only", &"{remoteName}/{mainBranchName}"],
                         &"failed to merge '{mainBranchName}' in " &
                         &"problem-specifications directory: '{probSpecsDir}'")

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

proc testsForGenerate(binaryPath: string) =
  suite "generate":
    const trackDir = testsDir / ".test_elixir_track_repo"
    let generateCmd = &"{binaryPath} -t {trackDir} generate"

    # Setup: clone a track repo, and checkout a known state
    setupExercismRepo("elixir", trackDir,
                      "91ccf91940f32aff3726c772695b2de167d8192a") # 2022-06-12

    test "`configlet generate` exits with 0 when there are no `.md.tpl` files":
      execAndCheck(0, generateCmd, "")

    test "and does not make a change":
      checkNoDiff(trackDir)

    # Valid placeholder syntax without spaces, and invalid slug
    prepareIntroductionFiles(trackDir, "%{concept:not-a-real-concept-slug}",
                             removeIntro = false)

    test "`configlet generate` exits with 1 for an invalid placeholder usage":
      execAndCheckExitCode(1, generateCmd)

    test "and does not make a change":
      checkNoDiff(trackDir)

    # Valid placeholder syntax without spaces, and valid slug
    prepareIntroductionFiles(trackDir, "%{concept:recursion}",
                             removeIntro = true)

    test "`configlet generate` exits with 0 for a valid `.md.tpl` file":
      execAndCheck(0, generateCmd, "")

    test "and writes the `introduction.md` file as expected":
      checkNoDiff(trackDir)

    # Valid placeholder syntax with spaces, and valid slug
    prepareIntroductionFiles(trackDir, "%{ concept : recursion }",
                             removeIntro = true)

    test "`configlet generate` exits with 0 for valid placeholder usage with spaces":
      execAndCheck(0, generateCmd, "")

    test "and writes the `introduction.md` file as expected":
      checkNoDiff(trackDir)

proc testsForCompletion(binaryPath: string) =
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

proc testsForFmt(binaryPath: static string) =
  const formattedTrackDir = testsDir / ".test_nim_track_repo"
  const unformattedTrackDir = testsDir / ".test_elixir_track_repo"

  # Setup: clone track repo, and checkout a known state (formatted)
  setupExercismRepo("nim", formattedTrackDir,
                    "ea91acb3edb6c7bc05dd3b050c0a566be6c3329e") # 2022-01-22

  # Setup: clone track repo, and checkout a known state (unformatted)
  setupExercismRepo("elixir", unformattedTrackDir,
                    "07448c4f870c15f8191196a2b01e8bf09708b8ce") # 2022-01-11

  const
    fmtBaseUnformatted = &"{binaryPath} -t {unformattedTrackDir} fmt"
    fmtBaseFormatted = &"{binaryPath} -t {formattedTrackDir} fmt"
    fmtUpdateUnformatted = &"{fmtBaseUnformatted} --update"
    fmtUpdateFormatted = &"{fmtBaseFormatted} --update"
    configJsonAbsolutePathUnFormatted = unformattedTrackDir / "config.json"
    unformattedHeader = &"Found 39 Concept Exercises and 118 Practice Exercises in {configJsonAbsolutePathUnFormatted}"

  suite "fmt, when the track `config.json` file is not formatted":
    test "prints the expected output, and exits with 1":
      const expectedOutput = fmt"""
        {unformattedHeader}
        Looking for exercises that lack a formatted '.meta/config.json', '.approaches/config.json'
        or '.articles/config.json' file...
        The below paths are relative to '{unformattedTrackDir}'
        Not formatted: config.json
        Not formatted: {"exercises"/"concept"/"basketball-website"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"bird-count"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"boutique-inventory"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"boutique-suggestions"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"bread-and-potions"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"captains-log"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"chessboard"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"city-office"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"community-garden"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"date-parser"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"dna-encoding"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"file-sniffer"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"freelancer-rates"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"german-sysadmin"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"guessing-game"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"high-school-sweetheart"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"high-score"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"kitchen-calculator"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"language-list"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"lasagna"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"library-fees"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"log-level"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"lucas-numbers"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"mensch-aergere-dich-nicht"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"name-badge"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"need-for-speed"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"new-passport"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"newsletter"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"pacman-rules"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"remote-control-car"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"rpg-character-sheet"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"rpn-calculator"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"rpn-calculator-inspection"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"rpn-calculator-output"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"secrets"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"stack-underflow"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"take-a-number"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"top-secret"/".meta"/"config.json"}
        Not formatted: {"exercises"/"concept"/"wine-cellar"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"accumulate"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"acronym"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"affine-cipher"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"all-your-base"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"allergies"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"alphametics"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"anagram"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"armstrong-numbers"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"atbash-cipher"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"bank-account"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"beer-song"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"binary-search"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"binary-search-tree"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"bob"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"book-store"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"bowling"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"change"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"circular-buffer"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"clock"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"collatz-conjecture"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"complex-numbers"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"connect"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"crypto-square"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"custom-set"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"darts"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"diamond"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"difference-of-squares"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"diffie-hellman"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"dnd-character"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"dominoes"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"dot-dsl"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"etl"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"flatten-array"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"food-chain"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"forth"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"gigasecond"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"go-counting"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"grade-school"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"grains"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"grep"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"hamming"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"hello-world"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"house"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"isbn-verifier"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"isogram"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"kindergarten-garden"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"knapsack"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"largest-series-product"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"leap"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"list-ops"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"luhn"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"markdown"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"matching-brackets"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"matrix"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"meetup"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"minesweeper"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"nth-prime"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"nucleotide-count"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"ocr-numbers"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"palindrome-products"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"pangram"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"parallel-letter-frequency"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"pascals-triangle"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"perfect-numbers"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"phone-number"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"pig-latin"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"poker"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"pov"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"prime-factors"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"protein-translation"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"proverb"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"pythagorean-triplet"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"queen-attack"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"rail-fence-cipher"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"raindrops"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"rational-numbers"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"react"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"rectangles"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"resistor-color"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"resistor-color-duo"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"resistor-color-trio"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"rna-transcription"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"robot-simulator"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"roman-numerals"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"rotational-cipher"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"run-length-encoding"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"saddle-points"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"satellite"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"say"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"scale-generator"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"scrabble-score"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"secret-handshake"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"series"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"sgf-parsing"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"sieve"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"simple-cipher"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"simple-linked-list"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"space-age"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"spiral-matrix"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"square-root"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"strain"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"sublist"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"sum-of-multiples"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"tournament"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"transpose"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"triangle"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"twelve-days"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"two-bucket"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"two-fer"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"variable-length-quantity"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"word-count"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"word-search"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"wordy"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"yacht"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"zebra-puzzle"/".meta"/"config.json"}
        Not formatted: {"exercises"/"practice"/"zipper"/".meta"/"config.json"}
      """.unindent()
      let cmd = fmtBaseUnformatted
      execAndCheck(1, cmd, expectedOutput)

  suite "fmt, for an exercise that is not formatted (prints the expected output, and exits with 1)":
    test "-e bob":
      const expectedOutput = fmt"""
        {unformattedHeader}
        Looking for exercises that lack a formatted '.meta/config.json', '.approaches/config.json'
        or '.articles/config.json' file...
        The below paths are relative to '{unformattedTrackDir}'
        Not formatted: {"exercises"/"practice"/"bob"/".meta"/"config.json"}
      """.unindent()
      execAndCheck(1, &"{fmtBaseUnformatted} -e bob", expectedOutput)

  suite "fmt, for an exercise that does not exist (prints the expected output, and exits with 1)":
    test "-e foo":
      const expectedOutput = fmt"""
        {unformattedHeader}
        The `-e, --exercise` option was used to specify an exercise slug, but `foo` is not an slug in the track config:
        {unformattedTrackDir / "config.json"}
      """.unindent()
      execAndCheck(1, &"{fmtBaseUnformatted} -e foo", expectedOutput)

  suite "fmt, with --update, without --yes, for an exercise that is not formatted (no diff, and exits with 1)":
    test "-e leap":
      let exitCode = execCmdEx(&"{fmtUpdateUnformatted} -e bob")[1]
      check exitCode == 1
      checkNoDiff(unformattedTrackDir)

  suite "fmt, with --update, for an exercise that is not formatted (no diff, and exits with 0)":
    test "-e bob":
      echo &"{fmtUpdateUnformatted} --yes -e bob"
      let exitCode = execCmdEx(&"{fmtUpdateUnformatted} --yes -e bob")[1]
      check exitCode == 0
      const expectedDiff = """
        --- exercises/practice/bob/.meta/config.json
        +++ exercises/practice/bob/.meta/config.json
        -  "blurb": "Bob is a lackadaisical teenager. In conversation, his responses are very limited.",
        +  "blurb": "Bob is a lackadaisical teenager. In conversation, his responses are very limited.",
      """.unindent()
      let configPath = "exercises" / "practice" / "bob" / ".meta" / "config.json"
      let trackDir = unformattedTrackDir
      testDiffThenRestore(trackDir, expectedDiff, configPath)

  suite "fmt, with --update, without --yes, for an exercise that is formatted (no diff, and exits with 0)":
    test "-e bob":
      let exitCode = execCmdEx(&"{fmtUpdateFormatted} -e bob")[1]
      check exitCode == 0
      checkNoDiff(formattedTrackDir)

  suite "fmt, with --update, for an exercise that is formatted (no diff, and exits with 0)":
    test "-e bob":
      let exitCode = execCmdEx(&"{fmtUpdateFormatted} --yes -e bob")[1]
      check exitCode == 0
      checkNoDiff(formattedTrackDir)

  suite "fmt, with --update, for an exercise that is not formatted (diff, and exits with 0)":
    test "-e bob":
      let exitCode = execCmdEx(&"{fmtUpdateUnformatted} --yes -e bob")[1]
      check exitCode == 0
      const expectedDiff = """
        --- exercises/practice/bob/.meta/config.json
        +++ exercises/practice/bob/.meta/config.json
        -  "blurb": "Bob is a lackadaisical teenager. In conversation, his responses are very limited.",
        +  "blurb": "Bob is a lackadaisical teenager. In conversation, his responses are very limited.",
      """.unindent()
      let configPath = "exercises" / "practice" / "bob" / ".meta" / "config.json"
      let trackDir = unformattedTrackDir
      testDiffThenRestore(trackDir, expectedDiff, configPath)

  suite "fmt, with --update (diff, and exits with 0)":
    test "all":
      let exitCode = execCmdEx(&"{fmtUpdateFormatted} --yes ")[1]
      check exitCode == 0
      const expectedDiff = """
        --- config.json
        +++ config.json
        -    "concept": [],
        -        "topics": null,
        -  "concepts": [],
        -  "key_features": [],
        +    "execution_mode/compiled",
        -    "typing/static",
        -    "typing/strong",
        -    "execution_mode/compiled",
        -    "platform/windows",
        -    "platform/mac",
        +    "platform/mac",
        +    "platform/windows",
        +    "typing/static",
        +    "typing/strong",
      """.unindent()
      let configPath = "config.json"
      let trackDir = formattedTrackDir
      testDiffThenRestore(trackDir, expectedDiff, configPath)

proc main =
  const
    binaryExt =
      when defined(windows): ".exe"
      else: ""
    binaryName = &"configlet{binaryExt}"
    binaryPath = repoRootDir / binaryName
    usageStart = &"Usage:\n  {binaryName} [global-options] <command> [command-options]"

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

  suite "version":
    test "--version":
      let (outp, exitCode) = execCmdEx(&"{binaryPath} --version")
      var major, minor, patch: int
      check:
        outp.scanf("$i.$i.$i", major, minor, patch)
        exitCode == 0

  suite "uuid":
    for cmd in ["uuid", "uuid -n 100", &"uuid -vq -n {repeat('9', 50)}"]:
      test &"{cmd}":
        let (outp, exitCode) = execCmdEx(&"{binaryPath} {cmd}")
        check exitCode == 0
        for line in outp.strip.splitLines:
          check line.isUuidV4

  when not defined(windows): # Ignore differences due to ".exe" and line endings.
    suite "README":
      test "README contains usage message":
        let (outp, _) = execCmdEx(&"{binaryPath} --help")
        let readmeContents = readFile(repoRootDir / "README.md")
        let usage = outp[outp.find("Usage")..^1]
        check:
          usage in readmeContents

  testsForSync(binaryPath)

  testsForGenerate(binaryPath)

  testsForCompletion(binaryPath)

  testsForFmt(binaryPath)

main()
{.used.}
