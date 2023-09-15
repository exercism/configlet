import std/[algorithm, enumutils, json, os, sets, strformat, strutils]
import ".."/[cli, lint/validators, types_exercise_config, types_track_config]

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

func addNewlineAndIndent*(s: var string, indentLevel: int) =
  ## Appends a newline and spaces (given by `indentLevel` multiplied by 2) to
  ## `s`.
  s.add '\n'
  const indentSize = 2
  let numSpaces = indentSize * indentLevel
  for _ in 1..numSpaces:
    s.add ' '

func addArray*(s: var string; key: string; val: openArray[string];
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

func addNull*(s: var string; key: string; indentLevel = 1) =
  ## Appends the pretty-printed JSON for a `key` and its null value to `s`.
  s.addNewlineAndIndent(indentLevel)
  escapeJson(key, s)
  s.add ": null,"

func addString*(s: var string; key, val: string; indentLevel = 1) =
  ## Appends the pretty-printed JSON for a `key` and its string `val` to `s`.
  s.addNewlineAndIndent(indentLevel)
  escapeJson(key, s)
  s.add ": "
  escapeJson(val, s)
  s.add ','

func addBool*(s: var string; key: string; val: bool; indentLevel = 1) =
  ## Appends the pretty-printed JSON for a `key` and its boolean `val` to `s`.
  s.addNewlineAndIndent(indentLevel)
  escapeJson(key, s)
  s.add ": "
  if val:
    s.add "true"
  else:
    s.add "false"
  s.add ','

func addInt*(s: var string; key: string; val: int; indentLevel = 1) =
  ## Appends the pretty-printed JSON for a `key` and its int `val` to `s`.
  s.addNewlineAndIndent(indentLevel)
  escapeJson(key, s)
  s.add ": "
  s.add $val
  s.add ','

func removeComma*(s: var string) =
  ## Removes the final character from `s`, if that character is a comma.
  if s[^1] == ',':
    s.setLen s.len-1

type
  PrettyMode* = enum
    pmSync
    pmFmt
