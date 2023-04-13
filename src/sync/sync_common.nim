import std/[algorithm, enumutils, json, options, os, sets, strformat, strutils]
import ".."/[cli, helpers, lint/validators, types_exercise_config, types_track_config,
             types_approaches_config, types_articles_config]

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

proc postHook*(e: ConceptExercise | PracticeExercise) =
  ## Quits with an error message if an `e.slug` value is not a kebab-case
  ## string.
  let s = e.slug.string
  if not isKebabCase(s):
    let msg = "Error: the track `config.json` file contains " &
              &"an exercise slug of \"{s}\", which is not a kebab-case string"
    stderr.writeLine msg
    quit 1

func getSlugs*(e: seq[ConceptExercise] | seq[PracticeExercise],
               withDeprecated = true): seq[Slug] =
  ## Returns a seq of the slugs in `e`, in alphabetical order.
  result = newSeqOfCap[Slug](e.len)
  for item in e:
    if withDeprecated or item.status != sDeprecated:
      result.add item.slug
  sort result

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

func addApproachesConfigPath*(s: var string) =
  const pathExerciseConfig = DirSep & joinPath(".approaches", "config.json")
  s.add pathExerciseConfig

func addArticlesConfigPath*(s: var string) =
  const pathExerciseConfig = DirSep & joinPath(".articles", "config.json")
  s.add pathExerciseConfig

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

func addNull(s: var string; key: string; indentLevel = 1) =
  ## Appends the pretty-printed JSON for a `key` and its null value to `s`.
  s.addNewlineAndIndent(indentLevel)
  escapeJson(key, s)
  s.add ": null,"

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

func addInt(s: var string; key: string; val: int; indentLevel = 1) =
  ## Appends the pretty-printed JSON for a `key` and its int `val` to `s`.
  s.addNewlineAndIndent(indentLevel)
  escapeJson(key, s)
  s.add ": "
  s.add $val
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
    if prettyMode == pmFmt and val.invalidator.len > 0:
      result.add fkInvalidator
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

    # If `editor` is missing and not empty, write it after `example`/`exemplar`.
    if fkEditor notin result and val.editor.len > 0:
      let insertionIndex = result.find(fkEx) + 1
      result.insert(fkEditor, insertionIndex)

    # If `invalidator` is missing and not empty, write it at the end.
    if fkInvalidator notin result and val.invalidator.len > 0:
      result.add fkInvalidator

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
    of fkInvalidator:
      s.addArray("invalidator", val.invalidator, indentLevel = inner)

  s.removeComma()
  s.addNewlineAndIndent(indentLevel)
  s.add "},"

func addRepresenter(s: var string; val: Representer; indentLevel = 1) =
  ## Appends the pretty-printed JSON for a `representer` key with value `val` to
  ## `s`.
  s.addNewlineAndIndent(indentLevel)
  escapeJson("representer", s)
  s.add ": {"
  s.addInt("version", val.version, indentLevel = indentLevel + 1)
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

func exerciseConfigKeyOrderForSync(originalKeyOrder: seq[
    ExerciseConfigKey]): seq[ExerciseConfigKey] =
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

func exerciseConfigKeyOrderForFmt(e: ConceptExerciseConfig |
                                     PracticeExerciseConfig): seq[
                                         ExerciseConfigKey] =
  result = @[eckAuthors]
  if e.contributors.isSome() and e.contributors.get().len > 0:
    result.add eckContributors
  result.add eckFiles
  if e.language_versions.len > 0:
    result.add eckLanguageVersions
  when e is ConceptExerciseConfig:
    if e.forked_from.isSome() and e.forked_from.get().len > 0:
      result.add eckForkedFrom
  when e is PracticeExerciseConfig:
    # Strips `"test_runner": true`.
    if e.test_runner.isSome() and not e.test_runner.get():
      result.add eckTestRunner
  if e.representer.isSome():
    result.add eckRepresenter
  if e.icon.len > 0:
    result.add eckIcon
  result.add eckBlurb
  if e.source.isSome():
    result.add eckSource
  if e.source_url.isSome():
    result.add eckSourceUrl
  if e.custom.isSome() and e.custom.get().len > 0:
    result.add eckCustom

func approachesConfigKeyOrderForFmt(e: ApproachesConfig): seq[ApproachesConfigKey] =
  result = @[]
  if e.introduction.authors.len > 0:
    result.add ackIntroduction
  if e.approaches.len > 0:
    result.add ackApproaches

func articlesConfigKeyOrderForFmt(e: ArticlesConfig): seq[ArticlesConfigKey] =
  result = @[]
  if e.articles.len > 0:
    result.add ackArticles

template addValOrNull(key, f: untyped) =
  if e.key.isSome():
    result.f(&"{key}", e.key.get())
  else:
    result.addNull(&"{key}")

proc prettyExerciseConfig*(e: ConceptExerciseConfig | PracticeExerciseConfig,
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
      exerciseConfigKeyOrderForSync(e.originalKeyOrder)
    of pmFmt:
      exerciseConfigKeyOrderForFmt(e)

  result = newStringOfCap(1000)
  result.add '{'
  for key in keys:
    case key
    of eckAuthors:
      result.addArray("authors", e.authors)
    of eckContributors:
      addValOrNull(contributors, addArray)
    of eckFiles:
      result.addFiles(e.files, prettyMode)
    of eckLanguageVersions:
      result.addString("language_versions", e.language_versions)
    of eckForkedFrom:
      when e is ConceptExerciseConfig:
        addValOrNull(forked_from, addArray)
    of eckTestRunner:
      when e is PracticeExerciseConfig:
        addValOrNull(test_runner, addBool)
    of eckRepresenter:
      if e.representer.isSome():
        result.addRepresenter(e.representer.get());
    of eckIcon:
      result.addString("icon", e.icon)
    of eckBlurb:
      result.addString("blurb", e.blurb)
    of eckSource:
      if e.source.isSome():
        result.addString("source", e.source.get())
    of eckSourceUrl:
      if e.source_url.isSome():
        result.addString("source_url", e.source_url.get())
    of eckCustom:
      addValOrNull(custom, addObject)
  result.removeComma()
  result.add "\n}\n"

func addApproachesIntroduction(result: var string;
                               val: ApproachesIntroductionConfig;
                               indentLevel = 1) =
  ## Appends the pretty-printed JSON for an `introduction` key with value `val` to
  ## `result`.
  result.addNewlineAndIndent(indentLevel)
  escapeJson("introduction", result)
  result.add ": {"
  result.addArray("authors", val.authors, indentLevel + 1)
  if val.contributors.len > 0:
    result.addArray("contributors", val.contributors, indentLevel + 1)
  result.removeComma()
  result.addNewlineAndIndent(indentLevel)
  result.add "},"

func addApproach(result: var string; val: ApproachConfig; indentLevel = 1) =
  ## Appends the pretty-printed JSON for an `approach` object with value `val` to
  ## `result`.
  result.addNewlineAndIndent(indentLevel)
  result.add "{"
  result.addString("uuid", val.uuid, indentLevel + 1)
  result.addString("slug", val.slug, indentLevel + 1)
  result.addString("title", val.title, indentLevel + 1)
  result.addString("blurb", val.blurb, indentLevel + 1)
  result.addArray("authors", val.authors, indentLevel + 1)
  if val.contributors.len > 0:
    result.addArray("contributors", val.contributors, indentLevel + 1)
  result.removeComma()
  result.addNewlineAndIndent(indentLevel)
  result.add "},"

func addApproaches(result: var string;
                   val: seq[ApproachConfig];
                   indentLevel = 1) =
  ## Appends the pretty-printed JSON for an `approaches` key with value `val` to
  ## `result`.
  result.addNewlineAndIndent(indentLevel)
  escapeJson("approaches", result)
  result.add ": ["
  for approach in val:
    result.addApproach(approach, indentLevel + 1)
  result.removeComma()
  result.addNewlineAndIndent(indentLevel)
  result.add "]"

func prettyApproachesConfig*(e: ApproachesConfig): string =
  ## Serializes `e` as pretty-printed JSON, using the canonical key order.
  let keys = approachesConfigKeyOrderForFmt(e)

  result = newStringOfCap(1000)
  result.add '{'
  for key in keys:
    case key
    of ackIntroduction:
      if e.introduction.authors.len > 0 or e.introduction.contributors.len > 0:
        result.addApproachesIntroduction(e.introduction)
    of ackApproaches:
      if e.approaches.len > 0:
        result.addApproaches(e.approaches)
  result.removeComma()
  result.add "\n}\n"

func addArticle(result: var string; val: ArticleConfig; indentLevel = 1) =
  ## Appends the pretty-printed JSON for an `article` object with value `val` to
  ## `result`.
  result.addNewlineAndIndent(indentLevel)
  result.add "{"
  result.addString("uuid", val.uuid, indentLevel + 1)
  result.addString("slug", val.slug, indentLevel + 1)
  result.addString("title", val.title, indentLevel + 1)
  result.addString("blurb", val.blurb, indentLevel + 1)
  result.addArray("authors", val.authors, indentLevel + 1)
  if val.contributors.len > 0:
    result.addArray("contributors", val.contributors, indentLevel + 1)
  result.removeComma()
  result.addNewlineAndIndent(indentLevel)
  result.add "},"

func addArticles(result: var string;
    val: seq[ArticleConfig]; indentLevel = 1) =
  ## Appends the pretty-printed JSON for an `articles` key with value `val` to
  ## `result`.
  result.addNewlineAndIndent(indentLevel)
  escapeJson("articles", result)
  result.add ": ["
  for article in val:
    result.addArticle(article, indentLevel + 1)
  result.removeComma()
  result.addNewlineAndIndent(indentLevel)
  result.add "]"

func prettyArticlesConfig*(e: ArticlesConfig): string =
  ## Serializes `e` as pretty-printed JSON, using the canonical key order.
  let keys = articlesConfigKeyOrderForFmt(e)

  result = newStringOfCap(1000)
  result.add '{'
  for key in keys:
    case key
    of ackArticles:
      if e.articles.len > 0:
        result.addArticles(e.articles)
  result.removeComma()
  result.add "\n}\n"
