import std/[os, osproc, strformat, strscans, strutils, unittest]
import exec, helpers, lint/validators, sync/probspecs
import "."/[binary_helpers]

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
      """.unindent().replace("\p", "\n")
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
      """.unindent().replace("\p", "\n")
      execAndCheck(1, &"{fmtBaseUnformatted} -e bob", expectedOutput)

  suite "fmt, for an exercise that does not exist (prints the expected output, and exits with 1)":
    test "-e foo":
      const expectedOutput = fmt"""
        {unformattedHeader}
        The `-e, --exercise` option was used to specify an exercise slug, but `foo` is not an slug in the track config:
        {unformattedTrackDir / "config.json"}
      """.unindent().replace("\p", "\n")
      execAndCheck(1, &"{fmtBaseUnformatted} -e foo", expectedOutput)

  suite "fmt, with --update, without --yes, for an exercise that is not formatted (no diff, and exits with 1)":
    test "-e bob":
      let exitCode = execCmdEx(&"{fmtUpdateUnformatted} -e bob")[1]
      check exitCode == 1
      checkNoDiff(unformattedTrackDir)

  suite "fmt, with --update, for an exercise that is not formatted (diff, and exits with 0)":
    test "-e bob":
      let exitCode = execCmdEx(&"{fmtUpdateUnformatted} --yes -e bob")[1]
      check exitCode == 0
      const expectedDiff = """
        --- exercises/practice/bob/.meta/config.json
        +++ exercises/practice/bob/.meta/config.json
        -  "blurb": "Bob is a lackadaisical teenager. In conversation, his responses are very limited.",
        +  "blurb": "Bob is a lackadaisical teenager. In conversation, his responses are very limited.",
      """.unindent().replace("\p", "\n")
      let configPath = "exercises" / "practice" / "bob" / ".meta" / "config.json"
      let trackDir = unformattedTrackDir
      testDiffThenRestore(trackDir, expectedDiff, configPath)

  suite "fmt, with --update --yes, for an exercise that is formatted (no diff, and exits with 0)":
    test "-e bob":
      let (outp, exitCode) = execCmdEx(&"{fmtUpdateFormatted} --yes -e bob")
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
      """.unindent().replace("\p", "\n")
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
      """.unindent().replace("\p", "\n")
      let configPath = "config.json"
      let trackDir = formattedTrackDir
      testDiffThenRestore(trackDir, expectedDiff, configPath)

proc main =
  testsForFmt(binaryPath)

main()
{.used.}
