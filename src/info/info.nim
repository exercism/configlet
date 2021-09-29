import std/[algorithm, os, sequtils, sets, strformat, strutils, terminal]
import ".."/[cli, lint/track_config]

# TODO: automatically update this at build-time?
# Last updated: 2021-09-17T05:00:00Z
const probSpecsSlugs = [
  "accumulate",
  "acronym",
  "affine-cipher",
  "all-your-base",
  "allergies",
  "alphametics",
  "anagram",
  "armstrong-numbers",
  "atbash-cipher",
  "bank-account",
  "beer-song",
  "binary",
  "binary-search",
  "binary-search-tree",
  "bob",
  "book-store",
  "bowling",
  "change",
  "circular-buffer",
  "clock",
  "collatz-conjecture",
  "complex-numbers",
  "connect",
  "counter",
  "crypto-square",
  "custom-set",
  "darts",
  "diamond",
  "difference-of-squares",
  "diffie-hellman",
  "dnd-character",
  "dominoes",
  "dot-dsl",
  "error-handling",
  "etl",
  "flatten-array",
  "food-chain",
  "forth",
  "gigasecond",
  "go-counting",
  "grade-school",
  "grains",
  "grep",
  "hamming",
  "hangman",
  "hello-world",
  "hexadecimal",
  "high-scores",
  "house",
  "isbn-verifier",
  "isogram",
  "kindergarten-garden",
  "knapsack",
  "largest-series-product",
  "leap",
  "ledger",
  "lens-person",
  "linked-list",
  "list-ops",
  "luhn",
  "markdown",
  "matching-brackets",
  "matrix",
  "meetup",
  "micro-blog",
  "minesweeper",
  "nth-prime",
  "nucleotide-codons",
  "nucleotide-count",
  "ocr-numbers",
  "octal",
  "paasio",
  "palindrome-products",
  "pangram",
  "parallel-letter-frequency",
  "pascals-triangle",
  "perfect-numbers",
  "phone-number",
  "pig-latin",
  "point-mutations",
  "poker",
  "pov",
  "prime-factors",
  "protein-translation",
  "proverb",
  "pythagorean-triplet",
  "queen-attack",
  "rail-fence-cipher",
  "raindrops",
  "rational-numbers",
  "react",
  "rectangles",
  "resistor-color",
  "resistor-color-duo",
  "resistor-color-trio",
  "rest-api",
  "reverse-string",
  "rna-transcription",
  "robot-name",
  "robot-simulator",
  "roman-numerals",
  "rotational-cipher",
  "run-length-encoding",
  "saddle-points",
  "satellite",
  "say",
  "scale-generator",
  "scrabble-score",
  "secret-handshake",
  "series",
  "sgf-parsing",
  "sieve",
  "simple-cipher",
  "simple-linked-list",
  "space-age",
  "spiral-matrix",
  "square-root",
  "strain",
  "sublist",
  "sum-of-multiples",
  "tournament",
  "transpose",
  "tree-building",
  "triangle",
  "trinary",
  "twelve-days",
  "two-bucket",
  "two-fer",
  "variable-length-quantity",
  "word-count",
  "word-search",
  "wordy",
  "yacht",
  "zebra-puzzle",
  "zipper",
].toHashSet()

func getConceptSlugs(concepts: Concepts): HashSet[string] =
  ## Returns the `slug` of every concept in `concepts`.
  result = initHashSet[string](concepts.len)
  for item in concepts:
    result.incl item.slug

func getPrereqs(practiceExercises: seq[PracticeExercise]): HashSet[string] =
  ## Returns the deduplicated set of `prerequisites` for every Practice Exercise
  ## in `practiceExercises`.
  result = initHashSet[string]()
  for practiceExercise in practiceExercises:
    for prereq in practiceExercise.prerequisites:
      result.incl prereq

func getPractices(practiceExercises: seq[PracticeExercise]): HashSet[string] =
  ## Returns the deduplicated set of `practices`for every Practice Exercise
  ## in `practiceExercises`.
  result = initHashSet[string]()
  for practiceExercise in practiceExercises:
    for item in practiceExercise.practices:
      result.incl item

proc header(s: string): string =
  if colorStdout:
    const ansi = ansiForegroundColorCode(fgBlue)
    &"{ansi}{s}{ansiResetCode}\n"
  else:
    &"{s}\n"

proc show[A](s: SomeSet[A], header: string): string =
  ## Returns a string containing a colorized (when appropriate) `header`, and
  ## then the elements of `s` in alphabetical order
  result = header(header)
  if s.len > 0:
    var elements = toSeq(s)
    sort elements
    for item in elements:
      result.add item
      result.add "\n"
  else:
    result.add "none\n"
  result.add "\n"

proc conceptsInfo(practiceExercises: seq[PracticeExercise],
                  concepts: seq[Concept]): string =
  let conceptSlugs = getConceptSlugs(concepts)
  let prereqs = getPrereqs(practiceExercises)
  let practices = getPractices(practiceExercises)

  let conceptsThatArentAPrereq = conceptSlugs - prereqs
  result = show(conceptsThatArentAPrereq,
      "Concepts that aren't a prerequisite for any Practice Exercise:")

  let conceptsThatArentPracticed = conceptSlugs - practices
  result.add show(conceptsThatArentPracticed,
      "Concepts that aren't practiced by any Practice Exercise:")

  let conceptsThatAreAPrereqButArentPracticed = prereqs - practices
  result.add show(conceptsThatAreAPrereqButArentPracticed,
      "Concepts that are a prerequisite, but aren't practiced by any Practice Exercise:")
  stripLineEnd(result)

func getSlugs(practiceExercises: seq[PracticeExercise]): HashSet[string] =
  result = initHashSet[string](practiceExercises.len)
  for practiceExercise in practiceExercises:
    result.incl practiceExercise.slug

proc unimplementedProbSpecsExercises(practiceExercises: seq[PracticeExercise],
                                     foregone: HashSet[string]): string =
  let practiceExerciseSlugs = getSlugs(practiceExercises)
  let unimplementedProbSpecsSlugs = probSpecsSlugs - practiceExerciseSlugs - foregone
  result = show(unimplementedProbSpecsSlugs,
      &"There are {unimplementedProbSpecsSlugs.len} exercises from " &
       "`exercism/problem-specifications` that are neither implemented nor " &
       "in `foregone`:")
  stripLineEnd(result)

func count(exercises: seq[ConceptExercise] |
                      seq[PracticeExercise]): tuple[visible: int, wip: int] =
  result = (0, 0)
  for exercise in exercises:
    case exercise.status
    of sMissing, sBeta, sActive:
      inc result.visible
    of sWip:
      inc result.wip
    of sDeprecated:
      discard

proc trackSummary(conceptExercises: seq[ConceptExercise],
                  practiceExercises: seq[PracticeExercise],
                  concepts: seq[Concept]): string =
  let (numConceptExercises, numConceptExercisesWip) = count(conceptExercises)
  let (numPracticeExercises, numPracticeExercisesWip) = count(practiceExercises)
  let numExercises = numConceptExercises + numPracticeExercises
  let numExercisesWip = numConceptExercisesWip + numPracticeExercisesWip
  let numConcepts = concepts.len
  result = header("Track summary:")
  result.add fmt"""
    {numConceptExercises:>3} Concept Exercises (plus {numConceptExercisesWip} work-in-progress)
    {numPracticeExercises:>3} Practice Exercises (plus {numPracticeExercisesWip} work-in-progress)
    {numExercises:>3} Exercises in total (plus {numExercisesWip} work-in-progress)
    {numConcepts:>3} Concepts""".unindent(4)

proc info*(conf: Conf) =
  let trackConfigPath = conf.trackDir / "config.json"

  if fileExists(trackConfigPath):
    let trackConfigContents = readFile(trackConfigPath)
    let trackConfig = TrackConfig.init(trackConfigContents)

    let exercises = trackConfig.exercises
    let conceptExercises = exercises.`concept`
    let practiceExercises = exercises.practice
    let foregone = exercises.foregone
    let concepts = trackConfig.concepts

    echo conceptsInfo(practiceExercises, concepts)
    echo unimplementedProbSpecsExercises(practiceExercises, foregone)
    echo trackSummary(conceptExercises, practiceExercises, concepts)
  else:
    showError &"file does not exist: {trackConfigPath}"
