import std/[algorithm, enumutils, json, options, os, sets, strformat, strutils]
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
  ##
  ## The character at `s[truncateLen-1]` must be the directory separator.
  # We use `os.normalizePathEnd` before calling this func.
  when not defined(release):
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

  ConceptExerciseFiles* = object
    originalKeyOrder: seq[FilesKey]
    solution*: seq[string]
    test*: seq[string]
    exemplar*: seq[string]
    editor*: seq[string]

  PracticeExerciseFiles* = object
    originalKeyOrder: seq[FilesKey]
    solution*: seq[string]
    test*: seq[string]
    example*: seq[string]
    editor*: seq[string]

  ConceptExerciseConfig* = object
    originalKeyOrder: seq[ExerciseConfigKey]
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
    originalKeyOrder*: seq[ExerciseConfigKey]
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

func identity(s: string): string =
  s

func parseEnumWithoutNormalizing[T: enum](s: string): T =
  ## Parses an enum `T`. This errors at compile-time if the given enum type
  ## contains multiple fields with the same string value.
  ##
  ## Raises `ValueError` if `s` is not a string value of `T`. That is, unlike
  ## `strutils.parseEnum`, no normalization is performed.
  genEnumCaseStmt(T, s, default = nil, T.low.ord, T.high.ord, identity)

func renameHook*(e: var (ConceptExerciseConfig | PracticeExerciseConfig); key: string) =
  ## Appends `key` to `e.originalKeyOrder`.
  ##
  ## This func does not rename anything, but it must be named `renameHook`.
  ## It just turns out that this hook is convenient for recording the key order,
  ## since it can access both the object being parsed and the key name - we
  ## don't need to redefine the whole `parseHook`.
  ##
  ## We want to record the key order so that `configlet sync` can write the
  ## keys in the same order that it saw them, so we can minimize noise in diffs
  ## and PRs. To instead format the JSON files without syncing, the user should
  ## run `configlet fmt`.
  ##
  ## With this func, we record the original key order as we do a single pass to
  ## parse the JSON, even though jsony tries not compromise on speed, and
  ## therefore:
  ## - does not keep track of the key order
  ## - and directly populates a strongly typed object (whose fields are in a
  ##   fixed order), minimizing intermediate allocations
  ##
  ## This is more efficient and elegant than doing a second pass to get the key
  ## order, or parsing into `JsonNode` and checking types after parse-time.
  try:
    let eck = parseEnumWithoutNormalizing[ExerciseConfigKey](key)
    e.originalKeyOrder.add eck
  except ValueError:
    discard

func renameHook*(f: var (ConceptExerciseFiles | PracticeExerciseFiles); key: string) =
  ## Appends `key` to `f.originalKeyOrder`.
  ##
  ## As with our other `renameHook`, this func does not actually rename anything.
  try:
    let fk = parseEnumWithoutNormalizing[FilesKey](key)
    f.originalKeyOrder.add fk
  except ValueError:
    discard

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
              indentLevel = 1) =
  ## Appends the pretty-printed JSON for a `key` and its string array `val` to
  ## `s`.
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

func addString(s: var string; key, val: string; indentLevel = 1) =
  ## Appends the pretty-printed JSON for a `key` and its string `val` to `s`.
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

type
  PrettyMode* = enum
    pmSync
    pmFmt

func filesKeyOrder(val: ConceptExerciseFiles | PracticeExerciseFiles;
                   prettyMode: PrettyMode): seq[FilesKey] =
  let fkEx = when val is ConceptExerciseFiles: fkExemplar else: fkExample
  if prettyMode == pmFmt or val.originalKeyOrder.len == 0:
    result = @[fkSolution, fkTest, fkEx]
    if prettyMode == pmFmt and val.editor.len > 0:
      result.add fkEditor
  else:
    result = val.originalKeyOrder
    # If `solution` is missing, write it first.
    if fkSolution notin result:
      result.insert(fkSolution, 0)

    # If `test` is missing, write it after `solution`.
    if fkTest notin result:
      let insertionIndex = result.find(fkSolution) + 1
      result.insert(fkTest, insertionIndex)

    # If `example` or `exemplar` are missing, write them after `test`.
    if fkEx notin result:
      let insertionIndex = result.find(fkTest) + 1
      result.insert(fkEx, insertionIndex)

func addFiles(s: var string; val: ConceptExerciseFiles | PracticeExerciseFiles;
              prettyMode: PrettyMode; indentLevel = 1) =
  ## Appends the pretty-printed JSON for a `files` key with value `val` to `s`.
  s.addNewlineAndIndent(indentLevel)
  escapeJson("files", s)
  s.add ": {"
  let keys = filesKeyOrder(val, prettyMode)
  let inner = indentLevel + 1

  for key in keys:
    case key
    of fkSolution:
      s.addArray("solution", val.solution, indentLevel = inner)
    of fkTest:
      s.addArray("test", val.test, indentLevel = inner)
    of fkExemplar:
      when val is ConceptExerciseFiles:
        s.addArray("exemplar", val.exemplar, indentLevel = inner)
    of fkExample:
      when val is PracticeExerciseFiles:
        s.addArray("example", val.example, indentLevel = inner)
    of fkEditor:
      s.addArray("editor", val.editor, indentLevel = inner)

  s.removeComma()
  s.addNewlineAndIndent(indentLevel)
  s.add "},"

proc addObject(s: var string; key: string; val: JsonNode; indentLevel = 1) =
  ## Appends the pretty-printed JSON for a `key` and its JSON object `val` to
  ## `s`.
  case val.kind
  of JObject:
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

func keyOrderForSync(originalKeyOrder: seq[ExerciseConfigKey]): seq[ExerciseConfigKey] =
  if originalKeyOrder.len == 0:
    return @[eckAuthors, eckFiles, eckBlurb]
  else:
    result = originalKeyOrder
    # If `authors` is missing, write it first.
    if eckAuthors notin result:
      result.insert(eckAuthors, 0)

    # If `files` is missing, write it after `contributors`, or `authors`.
    if eckFiles notin result:
      let insertionIndex = block:
        let iContributors = result.find(eckContributors)
        if iContributors > -1:
          iContributors + 1
        else:
          result.find(eckAuthors) + 1
      result.insert(eckFiles, insertionIndex)

    # If `blurb` is missing, write it before `source`, `source_url`, or
    # `custom`. If none of those exist, write `blurb` at the end.
    if eckBlurb notin result:
      let insertionIndex = block:
        var i = -1
        for item in [eckSource, eckSourceUrl, eckCustom]:
          i = result.find(item)
          if i > -1:
            break
        if i == -1:
          i = result.len # Inserting at `len`, means "add at the end".
        i
      result.insert(eckBlurb, insertionIndex)

func keyOrderForFmt(e: ConceptExerciseConfig |
                       PracticeExerciseConfig): seq[ExerciseConfigKey] =
  result = @[eckAuthors]
  if e.contributors.isSome() and e.contributors.get().len > 0:
    result.add eckContributors
  result.add eckFiles
  if e.language_versions.len > 0:
    result.add eckLanguageVersions
  when e is ConceptExerciseConfig:
    if e.forked_from.isSome() and e.forked_from.get().len > 0:
      result.add eckForkedFrom
    if e.icon.len > 0:
      result.add eckIcon
  when e is PracticeExerciseConfig:
    # Strips `"test_runner": true`.
    if e.test_runner.isSome() and not e.test_runner.get():
      result.add eckTestRunner
  result.add eckBlurb
  if e.source.len > 0:
    result.add eckSource
  if e.source_url.len > 0:
    result.add eckSourceUrl
  if e.custom.isSome() and e.custom.get().len > 0:
    result.add eckCustom

proc pretty*(e: ConceptExerciseConfig | PracticeExerciseConfig,
             prettyMode: PrettyMode): string =
  ## Serializes `e` as pretty-printed JSON, using:
  ## - the original key order if `prettyMode` is `pmSync`.
  ## - the canonical key order if `prettyMode` is `pmFmt`.
  ##
  ## Note that `pmSync` creates required keys if they are missing. For
  ## example, if an exercise `.meta/config.json` file is missing, or lacks a
  ## `files` key, we create the `files` key even when syncing only metadata.
  ## This is less "sync-like", but more ergonomic because the situation should
  ## only occur when creating a new exercise (as `configlet lint` exits non-zero
  ## if required keys are missing). This means that to create a blank
  ## `.meta/config.json`, a user can run just
  ##    $ configlet sync -uy --filepaths --metadata -e my-new-exercise
  ## and not need to also run
  ##    $ configlet fmt -e my-new-exercise
  let keys =
    case prettyMode
    of pmSync:
      keyOrderForSync(e.originalKeyOrder)
    of pmFmt:
      keyOrderForFmt(e)

  result = newStringOfCap(1000)
  result.add '{'
  for key in keys:
    case key
    of eckAuthors:
      result.addArray("authors", e.authors)
    of eckContributors:
      if e.contributors.isSome():
        result.addArray("contributors", e.contributors.get())
    of eckFiles:
      result.addFiles(e.files, prettyMode)
    of eckLanguageVersions:
      result.addString("language_versions", e.language_versions)
    of eckForkedFrom:
      when e is ConceptExerciseConfig:
        if e.forked_from.isSome():
          result.addArray("forked_from", e.forked_from.get())
    of eckIcon:
      when e is ConceptExerciseConfig:
        result.addString("icon", e.icon)
    of eckTestRunner:
      when e is PracticeExerciseConfig:
        if e.test_runner.isSome():
          result.addBool("test_runner", e.test_runner.get())
    of eckBlurb:
      result.addString("blurb", e.blurb)
    of eckSource:
      result.addString("source", e.source)
    of eckSourceUrl:
      result.addString("source_url", e.source_url)
    of eckCustom:
      if e.custom.isSome():
        result.addObject("custom", e.custom.get())
  result.removeComma()
  result.add "\n}\n"
