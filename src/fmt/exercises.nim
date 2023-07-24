import std/[json, options, os, sets, strformat, strutils]
import ".."/[helpers, sync/sync_common, types_exercise_config, types_track_config]

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

proc formatExerciseConfigFile*(exerciseKind: ExerciseKind,
                              configPath: string): string =
  ## Parses the `.meta/config.json` file at `configPath` and returns it in the
  ## canonical form.
  let exerciseConfig = ExerciseConfig.init(exerciseKind, configPath)
  case exerciseKind
  of ekConcept:
    prettyExerciseConfig(exerciseConfig.c, pmFmt)
  of ekPractice:
    prettyExerciseConfig(exerciseConfig.p, pmFmt)

