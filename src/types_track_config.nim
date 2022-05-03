import std/sets
import pkg/jsony
import "."/[cli, helpers]

type
  Slug* = distinct string ## A `slug` value in a track `config.json` file is a kebab-case string.

  Status* = enum
    sMissing = "missing"
    sWip = "wip"
    sBeta = "beta"
    sActive = "active"
    sDeprecated = "deprecated"

  # We can use a `HashSet` for `concepts`, `prerequisites`, `practices`, and
  # `foregone` because the first pass has already checked that each has unique
  # values.
  ConceptExercise* = object
    slug*: Slug
    concepts*: HashSet[string]
    prerequisites*: HashSet[string]
    status*: Status

  PracticeExercise* = object
    slug*: Slug
    practices*: HashSet[string]
    prerequisites*: HashSet[string]
    status*: Status

  Exercises* = object
    `concept`*: seq[ConceptExercise]
    practice*: seq[PracticeExercise]
    foregone*: HashSet[string]

  FilePatterns* = object
    solution*: seq[string]
    test*: seq[string]
    exemplar*: seq[string]
    example*: seq[string]
    editor*: seq[string]
    invalidator*: seq[string]

  Concept* = object
    name*: string
    slug*: string
    uuid*: string

  Concepts* = seq[Concept]

  TrackConfig* = object
    slug*: string
    exercises*: Exercises
    files*: FilePatterns
    concepts*: Concepts

  ExerciseKind* = enum
    ekConcept = "concept"
    ekPractice = "practice"

func `$`*(slug: Slug): string {.borrow.}

proc init*(T: typedesc[TrackConfig]; trackConfigContents: string): T =
  ## Deserializes `trackConfigContents` using `jsony` to a `TrackConfig` object.
  try:
    result = fromJson(trackConfigContents, TrackConfig)
  except jsony.JsonError:
    let msg = tidyJsonyErrorMsg(trackConfigContents)
    showError(msg)
