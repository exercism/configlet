import std/[hashes, options, sets]
import "."/[cli, helpers]

type
  Slug* = distinct string ## A `slug` value in a track `config.json` file is a kebab-case string.

type
  FilePatternsKey* = enum
    fpSolution = "solution"
    fpTest = "test"
    fpExemplar = "exemplar"
    fpExample = "example"
    fpEditor = "editor"
    fpInvalidator = "invalidator"

  TrackConfigKey* = enum
    tckLanguage = "language"
    tckSlug = "string"
    tckActive = "active"
    tckBlurb = "blurb"
    tckVersion = "version"
    tckExercises = "exercises"
    tckFiles = "files"
    tckConcepts = "concepts"
    tckTestRunner = "test_runner"
    tckOnlineEditor = "online_editor"
    tckKeyFeatures = "key_features"
    tckStatus = "status"
    tckTags = "tags"

  Status* = enum
    sMissing = "missing"
    sWip = "wip"
    sBeta = "beta"
    sActive = "active"
    sDeprecated = "deprecated"

  # We can use an `OrderedSet` for `concepts`, `prerequisites`, `practices`, and
  # `foregone` because the first pass has already checked that each has unique
  # values, but we want to retain insertion order to reduce churn.
  ConceptExercise* = object
    slug*: Slug
    name*: string
    uuid*: string
    concepts*: OrderedSet[string]
    prerequisites*: OrderedSet[string]
    status*: Status

  PracticeExercise* = object
    slug*: Slug
    name*: string
    uuid*: string
    practices*: OrderedSet[string]
    prerequisites*: OrderedSet[string]
    difficulty*: int
    topics*: Option[OrderedSet[string]]
    status*: Status

  Exercises* = object
    `concept`*: seq[ConceptExercise]
    practice*: seq[PracticeExercise]
    foregone*: OrderedSet[string]

  FilePatterns* = object
    solution*: seq[string]
    test*: seq[string]
    exemplar*: seq[string]
    example*: seq[string]
    editor*: seq[string]
    invalidator*: seq[string]

  IndentStyle* = enum
    isSpace = "space"
    isTab = "tab"

  OnlineEditor* = object
    indentStyle*: IndentStyle
    indentSize*: int
    highlightjsLanguage*: string

  ConceptTags* = object
    all*: seq[string]
    `any`*: seq[string]
    `not`*: seq[string]

  Concept* = object
    name*: string
    slug*: string
    uuid*: string
    tags*: Option[ConceptTags]

  Concepts* = seq[Concept]

  KeyFeature* = object
    icon*: string
    title*: string
    content*: string

  KeyFeatures* = seq[KeyFeature]

  TestRunner* = object
    averageRunTime*: int

  TrackStatus* = object
    conceptExercises*: bool
    testRunner*: bool
    representer*: bool
    analyzer*: bool

  TrackConfig* = object
    language*: string
    slug*: string
    active*: bool
    blurb*: string
    version*: int
    exercises*: Exercises
    files*: FilePatterns
    concepts*: Concepts
    testRunner*: TestRunner
    onlineEditor*: OnlineEditor
    keyFeatures*: KeyFeatures
    status*: TrackStatus
    tags*: OrderedSet[string]

func `$`*(slug: Slug): string {.borrow.}
func `==`*(x, y: Slug): bool {.borrow.}
func `<`*(x, y: Slug): bool {.borrow.}
func len*(slug: Slug): int {.borrow.}
func hash*(slug: Slug): Hash {.borrow.}
func add*(s: var Slug, c: char) {.borrow.}

proc init*(T: typedesc[TrackConfig]; trackConfigContents: string): T =
  ## Deserializes `trackConfigContents` using `jsony` to a `TrackConfig` object.
  try:
    result = fromJson(trackConfigContents, TrackConfig)
  except jsony.JsonError:
    let msg = tidyJsonyErrorMsg(trackConfigContents)
    showError(msg)
