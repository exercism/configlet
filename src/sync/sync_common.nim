import std/[options, strformat, strutils]
import pkg/jsony
import ".."/cli

proc userSaysYes*(syncKind: SyncKind): bool =
  stderr.write &"sync the above {syncKind} ([y]es/[n]o)? "
  let resp = stdin.readLine().toLowerAscii()
  if resp == "y" or resp == "yes":
    result = true

{.push hint[Name]:off.}

type
  ExerciseKind* = enum
    ekConcept = "concept"
    ekPractice = "practice"

  FilePatterns* = object
    solution*: seq[string]
    test*: seq[string]
    exemplar*: seq[string]
    example*: seq[string]
    editor*: seq[string]

  # TODO: can we refactor the below types as variant objects?
  #
  # The difficulty: an exercise `config.json` file does not contain a shared
  # key that we can use as a discriminator.
  #
  # For example, we cannot simply write:
  #
  #   ExerciseConfig* = object
  #     authors: seq[string]
  #     contributors: seq[string]
  #     files*: Files
  #     language_versions: string
  #     blurb*: string
  #     source*: string
  #     source_url*: string
  #     case kind*: ExerciseKind
  #     of ekConcept:
  #       forked_from: seq[string]
  #       icon: string
  #     of ekPractice:
  #       test_runner: Option[bool]
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

  ConceptExerciseFiles* = object
    solution*: seq[string]
    test*: seq[string]
    exemplar*: seq[string]
    editor*: seq[string]

  PracticeExerciseFiles* = object
    solution*: seq[string]
    test*: seq[string]
    example*: seq[string]
    editor*: seq[string]

  ConceptExerciseConfig* = object
    authors: seq[string]
    contributors: seq[string]
    files*: ConceptExerciseFiles
    language_versions: string
    blurb*: string
    source*: string
    source_url*: string
    # The below are unique to Concept Exercises
    forked_from: seq[string]
    icon: string

  PracticeExerciseConfig* = object
    authors: seq[string]
    contributors: seq[string]
    files*: PracticeExerciseFiles
    language_versions: string
    blurb*: string
    source*: string
    source_url*: string
    # The below are unique to Practice Exercises
    test_runner*: Option[bool]

  ExerciseConfig* = object
    case kind*: ExerciseKind
    of ekConcept:
      c*: ConceptExerciseConfig
    of ekPractice:
      p*: PracticeExerciseConfig

  PathAndUpdatedExerciseConfig* = object
    path*: string
    exerciseConfig*: ExerciseConfig

{.pop.}

proc parseFile*(path: string, T: typedesc): T =
  ## Parses the JSON file at `path` into `T`.
  readFile(path).fromJson(T)
