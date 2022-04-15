import std/[json, options]

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
  #       icon: string
  #     of ekPractice:
  #       test_runner: Option[bool]
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
    eckIcon = "icon"
    eckTestRunner = "test_runner"
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
    icon*: string                     ## Allowed only for a Concept Exercise.
    blurb*: string
    source*: string
    source_url*: string
    custom*: Option[JsonNode]

  PracticeExerciseConfig* = object
    originalKeyOrder*: seq[ExerciseConfigKey]
    authors*: seq[string]
    contributors*: Option[seq[string]]
    files*: PracticeExerciseFiles
    language_versions*: string
    test_runner*: Option[bool] ## Allowed only for a Practice Exercise.
    # The below fields are synced for a Practice Exercise that exists in the
    # `exercism/problem-specifications` repo.
    blurb*: string
    source*: string
    source_url*: string
    custom*: Option[JsonNode]

{.pop.}
