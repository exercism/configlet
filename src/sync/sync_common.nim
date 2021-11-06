import std/[algorithm, json, options, strformat, strutils]
import pkg/jsony
import ".."/[cli, helpers, lint/validators]

proc userSaysYes*(syncKind: SyncKind): bool =
  while true:
    stderr.write &"sync the above {syncKind} ([y]es/[n]o)? "
    case stdin.readLine().toLowerAscii()
    of "y", "yes":
      return true
    of "n", "no":
      return false
    else:
      stderr.writeLine "Unrecognized response. Please answer [y]es or [n]o."

{.push hint[Name]: off.}

type
  Slug* = distinct string # A kebab-case string.

  ConceptExercise* = object
    slug*: Slug

  PracticeExercise* = object
    slug*: Slug

  Exercises* = object
    `concept`*: seq[ConceptExercise]
    practice*: seq[PracticeExercise]

  FilePatterns* = object
    solution*: seq[string]
    test*: seq[string]
    exemplar*: seq[string]
    example*: seq[string]
    editor*: seq[string]

  TrackConfig* = object
    exercises*: Exercises
    files*: FilePatterns

proc postHook*(e: ConceptExercise | PracticeExercise) =
  ## Quits with an error message if a `slug` value is not a kebab-case string.
  let s = e.slug.string
  if not isKebabCase(s):
    let msg = "Error: the track `config.json` file contains " &
              &"an exercise slug of \"{s}\", which is not a kebab-case string"
    stderr.writeLine msg
    quit 1

func `==`*(x, y: Slug): bool {.borrow.}
func `<`*(x, y: Slug): bool {.borrow.}

func getSlugs*(e: seq[ConceptExercise] | seq[PracticeExercise]): seq[Slug] =
  ## Returns a seq of the slugs `e`, in alphabetical order.
  result = newSeq[Slug](e.len)
  for i, item in e:
    result[i] = item.slug
  sort result

func len*(slug: Slug): int {.borrow.}
func `$`*(slug: Slug): string {.borrow.}

type
  ExerciseKind* = enum
    ekConcept = "concept"
    ekPractice = "practice"

  # TODO: can we refactor the below types as variant objects?
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
    contributors: Option[seq[string]]
    files*: ConceptExerciseFiles
    language_versions: string
    forked_from: Option[seq[string]] # Allowed only for a Concept Exercise
    icon: string                     # Allowed only for a Concept Exercises
    blurb*: string
    source*: string
    source_url*: string

  PracticeExerciseConfig* = object
    authors: seq[string]
    contributors: Option[seq[string]]
    files*: PracticeExerciseFiles
    language_versions: string
    test_runner*: Option[bool] # Allowed only for a Practice Exercise
    # The below fields are synced for a Practice Exercise that exists in the
    # `exercism/problem-specifications` repo.
    blurb*: string
    source*: string
    source_url*: string

{.pop.}

proc parseFile*(path: string, T: typedesc): T =
  ## Parses the JSON file at `path` into `T`.
  let contents =
    try:
      readFile(path)
    except IOError:
      let msg = getCurrentExceptionMsg()
      stderr.writeLine &"Error: {msg}"
      quit 1
  if contents.len > 0:
    try:
      contents.fromJson(T)
    except jsony.JsonError:
      let jsonyMsg = getCurrentExceptionMsg()
      let details = tidyJsonyMessage(jsonyMsg, contents)
      let msg = &"JSON parsing error:\n{path}{details}"
      stderr.writeLine msg
      quit 1
  else:
    T()

func addNewlineAndIndent(s: var string, indentLevel: int) =
  ## Adds a newline and spaces to `s`.
  s.add '\n'
  const indentSize = 2
  let numSpaces = indentSize * indentLevel
  for _ in 1..numSpaces:
    s.add ' '

func addArray(s: var string; key: string; val: openArray[string];
              isRequired = true, indentLevel = 1) =
  if isRequired or val.len > 0:
    s.addNewlineAndIndent(indentLevel)
    escapeJson(key, s)
    s.add ": "
    if val.len > 0:
      s.add '['
      let inner = indentLevel + 1
      for i, item in val:
        if i > 0:
          s.add ','
        s.addNewlineAndIndent(inner)
        escapeJson(item, s)
      s.addNewlineAndIndent(indentLevel)
      s.add "],"
    else:
      s.add "[],"

func addString(s: var string; key, val: string; isRequired = true,
               indentLevel = 1) =
  if isRequired or val.len > 0:
    s.addNewlineAndIndent(indentLevel)
    escapeJson(key, s)
    s.add ": "
    escapeJson(val, s)
    s.add ','

func addFiles(s: var string; val: ConceptExerciseFiles | PracticeExerciseFiles,
              indentLevel = 1) =
  s.addNewlineAndIndent(indentLevel)
  escapeJson("files", s)
  s.add ": {"
  let inner = indentLevel + 1
  s.addArray("solution", val.solution, indentLevel = inner)
  s.addArray("test", val.test, indentLevel = inner)
  s.addArray("editor", val.editor, isRequired = false, indentLevel = inner)
  when val is ConceptExerciseFiles:
    s.addArray("exemplar", val.exemplar, indentLevel = inner)
  when val is PracticeExerciseFiles:
    s.addArray("example", val.example, indentLevel = inner)
  s.setLen s.len-1 # Remove comma.
  s.addNewlineAndIndent(indentLevel)
  s.add "},"

func pretty*(e: ConceptExerciseConfig | PracticeExerciseConfig): string =
  result = newStringOfCap(100)
  result.add '{'
  result.addArray("authors", e.authors)
  if e.contributors.isSome():
    result.addArray("contributors", e.contributors.get(), isRequired = false)
  result.addFiles(e.files)
  result.addString("language_versions", e.language_versions, isRequired = false)
  when e is ConceptExerciseConfig:
    if e.forked_from.isSome():
      result.addArray("forked_from", e.forked_from.get(), isRequired = false)
    result.addString("icon", e.icon, isRequired = false)
  when e is PracticeExerciseConfig:
    # Keep the `test_runner` key only when it was present in the
    # `.meta/config.json` that we parsed, and had the value `false`.
    # The spec says that an omitted `test_runner` key implies the value `true`.
    if e.test_runner.isSome() and not e.test_runner.get():
      result.addString("test_runner", "false") # Hack.
  result.addString("blurb", e.blurb)
  result.addString("source", e.source, isRequired = false)
  result.addString("source_url", e.source_url, isRequired = false)
  result.setLen result.len-1 # Remove comma.
  result.add "\n}\n"
