import std/[json, options]
import "."/helpers

# Silence the styleCheck hint for `source_url`.
{.push hint[Name]: off.}

type
  # TODO: can/should we refactor the below types as variant objects?
  #
  # The difficulty: an exercise `config.json` file does not contain a shared
  # key that we can use as a discriminator.
  #
  # For example, we cannot simply write:
  #
  #   ExerciseConfig* = object
  #     authors: seq[string]
  #     contributors: Option[seq[string]]
  #     files*: Files
  #     language_versions: string
  #     case kind*: ExerciseKind
  #     of ekConcept:
  #       forked_from: Option[seq[string]]
  #     of ekPractice:
  #       test_runner: Option[bool]
  #     icon: string
  #     blurb*: string
  #     source*: string
  #     source_url*: string
  #     custom*: Option[JsonNode]
  #
  # and parse with `jsony.fromJson` because the JSON does not actually contain a
  # `kind` key. Furthermore, the unique keys for Practice and Concept exercises
  # are optional, and so we cannot use them either - if those keys are missing,
  # we cannot determine the `kind`.
  #
  # However, the `files` key _is_ required, and within that, the `exemplar` and
  # `example` keys _are_ required. So while we cannot write:
  #
  #   Files* = object
  #     solution*: seq[string]
  #     test*: seq[string]
  #     editor*: seq[string]
  #     invalidator*: seq[string]
  #     case kind*: ExerciseKind
  #     of ekConcept:
  #       exemplar*: seq[string]
  #     of ekPractice:
  #       example*: seq[string]
  #
  # (again because the JSON `files` data does not contain a `kind` key) we can
  # theoretically determine the `kind` by the presence of the `exemplar` or
  # `example` keys.
  #
  # Alternative hack: inject two `kind` key/value pairs into each exercise
  # `.meta/config.json` file after we read it, but before parsing with `jsony`.

  ExerciseConfigKey* = enum
    eckAuthors = "authors"
    eckContributors = "contributors"
    eckFiles = "files"
    eckLanguageVersions = "language_versions"
    eckForkedFrom = "forked_from"
    eckTestRunner = "test_runner"
    eckRepresenter = "representer"
    eckIcon = "icon"
    eckBlurb = "blurb"
    eckSource = "source"
    eckSourceUrl = "source_url"
    eckCustom = "custom"

  FilesKey* = enum
    fkSolution = "solution"
    fkTest = "test"
    fkExemplar = "exemplar"
    fkExample = "example"
    fkEditor = "editor"
    fkInvalidator = "invalidator"

  Representer* = object
    version*: int

  ConceptExerciseFiles* = object
    originalKeyOrder*: seq[FilesKey]
    solution*: seq[string]
    test*: seq[string]
    exemplar*: seq[string]
    editor*: seq[string]
    invalidator*: seq[string]

  PracticeExerciseFiles* = object
    originalKeyOrder*: seq[FilesKey]
    solution*: seq[string]
    test*: seq[string]
    example*: seq[string]
    editor*: seq[string]
    invalidator*: seq[string]

  ConceptExerciseConfig* = object
    originalKeyOrder*: seq[ExerciseConfigKey]
    authors*: seq[string]
    contributors*: Option[seq[string]]
    files*: ConceptExerciseFiles
    language_versions*: string
    forked_from*: Option[seq[string]] ## Allowed only for a Concept Exercise.
    representer*: Option[Representer]
    icon*: string
    blurb*: string
    source*: Option[string]
    source_url*: Option[string]
    custom*: Option[JsonNode]

  PracticeExerciseConfig* = object
    originalKeyOrder*: seq[ExerciseConfigKey]
    authors*: seq[string]
    contributors*: Option[seq[string]]
    files*: PracticeExerciseFiles
    language_versions*: string
    test_runner*: Option[bool] ## Allowed only for a Practice Exercise.
    representer*: Option[Representer]
    icon*: string
    # The below fields are synced for a Practice Exercise that exists in the
    # `exercism/problem-specifications` repo.
    blurb*: string
    source*: Option[string]
    source_url*: Option[string]
    custom*: Option[JsonNode]

  ExerciseKind* = enum
    ekConcept = "concept"
    ekPractice = "practice"

  ExerciseConfig* = object
    case kind*: ExerciseKind
    of ekConcept:
      c*: ConceptExerciseConfig
    of ekPractice:
      p*: PracticeExerciseConfig
{.pop.}

proc init*(T: typedesc[ExerciseConfig], kind: ExerciseKind,
           trackExerciseConfigPath: string): T =
  case kind
  of ekConcept: T(
    kind: kind,
    c: parseFile(trackExerciseConfigPath, ConceptExerciseConfig)
  )
  of ekPractice: T(
    kind: kind,
    p: parseFile(trackExerciseConfigPath, PracticeExerciseConfig)
  )