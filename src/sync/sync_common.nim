import std/[algorithm, json, options, os, strformat, strutils]
import pkg/jsony
import ".."/[cli, helpers, lint/validators]

proc userSaysYes*(syncKind: SyncKind): bool =
  ## Asks the user if they want to sync the given `syncKind`, and returns `true`
  ## if they confirm.
  while true:
    stderr.write &"sync the above {syncKind} ([y]es/[n]o)? "
    case stdin.readLine().toLowerAscii()
    of "y", "yes":
      return true
    of "n", "no":
      return false
    else:
      stderr.writeLine "Unrecognized response. Please answer [y]es or [n]o."

type
  Slug* = distinct string ## A `slug` value in a track `config.json` file is a kebab-case string.

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
  ## Quits with an error message if an `e.slug` value is not a kebab-case
  ## string.
  let s = e.slug.string
  if not isKebabCase(s):
    let msg = "Error: the track `config.json` file contains " &
              &"an exercise slug of \"{s}\", which is not a kebab-case string"
    stderr.writeLine msg
    quit 1

func `==`*(x, y: Slug): bool {.borrow.}
func `<`*(x, y: Slug): bool {.borrow.}

func getSlugs*(e: seq[ConceptExercise] | seq[PracticeExercise]): seq[Slug] =
  ## Returns a seq of the slugs in `e`, in alphabetical order.
  result = newSeq[Slug](e.len)
  for i, item in e:
    result[i] = item.slug
  sort result

func len*(slug: Slug): int {.borrow.}
func `$`*(slug: Slug): string {.borrow.}

func truncateAndAdd*(s: var string, truncateLen: int, slug: Slug) =
  ## Truncates `s` to `truncateLen`, then appends `slug`.
  assert truncateLen <= s.len and s[truncateLen-1] == DirSep
  s.setLen truncateLen
  s.add slug.string

func addDocsDir*(s: var string) =
  const pathDocs = DirSep & ".docs"
  s.add pathDocs

func addMetadataTomlPath*(s: var string) =
  const pathMetadataToml = DirSep & "metadata.toml"
  s.add pathMetadataToml

func addExerciseConfigPath*(s: var string) =
  const pathExerciseConfig = DirSep & joinPath(".meta", "config.json")
  s.add pathExerciseConfig

type
  ExerciseKind* = enum
    ekConcept = "concept"
    ekPractice = "practice"

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
    forked_from: Option[seq[string]] ## Allowed only for a Concept Exercise.
    icon: string                     ## Allowed only for a Concept Exercise.
    blurb*: string
    source*: string
    source_url*: string
    custom*: Option[JsonNode]

  PracticeExerciseConfig* = object
    authors: seq[string]
    contributors: Option[seq[string]]
    files*: PracticeExerciseFiles
    language_versions: string
    test_runner*: Option[bool] ## Allowed only for a Practice Exercise.
    # The below fields are synced for a Practice Exercise that exists in the
    # `exercism/problem-specifications` repo.
    blurb*: string
    source*: string
    source_url*: string
    custom*: Option[JsonNode]

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
  ## Appends a newline and spaces (given by `indentLevel` multiplied by 2) to
  ## `s`.
  s.add '\n'
  const indentSize = 2
  let numSpaces = indentSize * indentLevel
  for _ in 1..numSpaces:
    s.add ' '

func addArray(s: var string; key: string; val: openArray[string];
              isRequired = true, indentLevel = 1) =
  ## Appends the pretty-printed JSON for a `key` and its string array `val` to
  ## `s`.
  ##
  ## Does not append if both `isRequired` is `false` and `val` is empty.
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
  ## Appends the pretty-printed JSON for a `key` and its string `val` to `s`.
  ##
  ## Does not append if both `isRequired` is `false` and `val` is empty.
  if isRequired or val.len > 0:
    s.addNewlineAndIndent(indentLevel)
    escapeJson(key, s)
    s.add ": "
    escapeJson(val, s)
    s.add ','

func addBool(s: var string; key: string; val: bool; indentLevel = 1) =
  ## Appends the pretty-printed JSON for a `key` and its boolean `val` to `s`.
  s.addNewlineAndIndent(indentLevel)
  escapeJson(key, s)
  s.add ": "
  if val:
    s.add "true"
  else:
    s.add "false"
  s.add ','

func removeComma(s: var string) =
  ## Removes the final character from `s`, if that character is a comma.
  if s[^1] == ',':
    s.setLen s.len-1

func addFiles(s: var string; val: ConceptExerciseFiles | PracticeExerciseFiles,
              indentLevel = 1) =
  ## Appends the pretty-printed JSON for a `files` key with value `val` to `s`.
  s.addNewlineAndIndent(indentLevel)
  escapeJson("files", s)
  s.add ": {"
  let inner = indentLevel + 1
  s.addArray("solution", val.solution, indentLevel = inner)
  s.addArray("test", val.test, indentLevel = inner)
  when val is ConceptExerciseFiles:
    s.addArray("exemplar", val.exemplar, indentLevel = inner)
  when val is PracticeExerciseFiles:
    s.addArray("example", val.example, indentLevel = inner)
  s.addArray("editor", val.editor, isRequired = false, indentLevel = inner)
  s.removeComma()
  s.addNewlineAndIndent(indentLevel)
  s.add "},"

proc addObject(s: var string; key: string; val: JsonNode; indentLevel = 1) =
  ## Appends the pretty-printed JSON for a `key` and its JSON object `val` to
  ## `s`.
  case val.kind
  of JObject:
    if val.len > 0:
      s.addNewlineAndIndent(indentLevel)
      escapeJson(key, s)
      s.add ": "
      let pretty = val.pretty()
      for c in pretty:
        if c == '\n':
          s.addNewlineAndIndent(indentLevel)
        else:
          s.add c
  else:
    stderr.writeLine &"The value of a `{key}` key is not a JSON object:"
    stderr.writeLine val.pretty()
    quit 1

proc pretty*(e: ConceptExerciseConfig | PracticeExerciseConfig): string =
  ## Serializes `e` as pretty-printed JSON.
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
      result.addBool("test_runner", false)
  result.addString("blurb", e.blurb)
  result.addString("source", e.source, isRequired = false)
  result.addString("source_url", e.source_url, isRequired = false)
  if e.custom.isSome():
    result.addObject("custom", e.custom.get())
  result.removeComma()
  result.add "\n}\n"
