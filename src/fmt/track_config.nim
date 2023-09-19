import std/[algorithm, sequtils, json, options, sets, strformat]
import pkg/jsony
import ".."/[helpers, sync/sync_common, types_track_config]

func trackConfigKeyOrderForFmt(e: TrackConfig): seq[TrackConfigKey] =
  result = @[]
  if e.language.len > 0:
    result.add tckLanguage
  if e.slug.len > 0:
    result.add tckSlug
  result.add tckActive
  result.add tckStatus
  if e.blurb.len > 0:
    result.add tckBlurb
  result.add tckVersion
  result.add tckOnlineEditor
  if e.testRunner.averageRunTime > 0:
    result.add tckTestRunner
  if e.files.solution.len > 0 or
     e.files.test.len > 0 or
     e.files.exemplar.len > 0 or
     e.files.example.len > 0 or
     e.files.editor.len > 0 or
     e.files.invalidator.len > 0:
    result.add tckFiles
  if e.exercises.`concept`.len > 0 or
     e.exercises.practice.len > 0 or
     e.exercises.foregone.len > 0:
    result.add tckExercises
  if e.concepts.len > 0:
    result.add tckConcepts
  if e.keyFeatures.len > 0:
    result.add tckKeyFeatures
  if e.tags.len > 0:
    result.add tckTags

func addStatus(result: var string; val: TrackStatus; indentLevel = 1) =
  result.addNewlineAndIndent(indentLevel)
  escapeJson("status", result)
  result.add ": {"
  result.addBool("concept_exercises", val.conceptExercises,
      indentLevel = indentLevel + 1)
  result.addBool("test_runner", val.testRunner, indentLevel = indentLevel + 1)
  result.addBool("representer", val.representer, indentLevel = indentLevel + 1)
  result.addBool("analyzer", val.analyzer, indentLevel = indentLevel + 1)
  result.removeComma()
  result.addNewlineAndIndent(indentLevel)
  result.add "},"

func addTestRunner(result: var string; val: TestRunner; indentLevel = 1) =
  result.addNewlineAndIndent(indentLevel)
  escapeJson("test_runner", result)
  result.add ": {"
  result.addInt("average_run_time", val.averageRunTime,
      indentLevel = indentLevel + 1)
  result.removeComma()
  result.addNewlineAndIndent(indentLevel)
  result.add "},"

func addOnlineEditor(result: var string; val: OnlineEditor; indentLevel = 1) =
  result.addNewlineAndIndent(indentLevel)
  escapeJson("online_editor", result)
  result.add ": {"
  result.addString("indent_style", $val.indentStyle, indentLevel = indentLevel + 1)
  result.addInt("indent_size", val.indentSize, indentLevel = indentLevel + 1)
  if val.highlightjsLanguage.len > 0:
    result.addString("highlightjs_language", val.highlightjsLanguage,
        indentLevel = indentLevel + 1)
  result.removeComma()
  result.addNewlineAndIndent(indentLevel)
  result.add "},"

func addFiles(result: var string; val: FilePatterns; indentLevel = 1) =
  result.addNewlineAndIndent(indentLevel)
  escapeJson("files", result)
  result.add ": {"
  if val.solution.len > 0:
    result.addArray("solution", val.solution, indentLevel = indentLevel + 1)
  if val.test.len > 0:
    result.addArray("test", val.test, indentLevel = indentLevel + 1)
  if val.example.len > 0:
    result.addArray("example", val.example, indentLevel = indentLevel + 1)
  if val.exemplar.len > 0:
    result.addArray("exemplar", val.exemplar, indentLevel = indentLevel + 1)
  if val.editor.len > 0:
    result.addArray("editor", val.editor, indentLevel = indentLevel + 1)
  if val.invalidator.len > 0:
    result.addArray("invalidator", val.invalidator, indentLevel = indentLevel + 1)
  result.removeComma()
  result.addNewlineAndIndent(indentLevel)
  result.add "},"

func addTags(result: var string; val: HashSet[string]; indentLevel = 1) =
  ## Appends the pretty-printed JSON for an `val` key with value `tags`
  ## to `result`.
  var tags = toSeq(val)
  sort tags

  result.addArray("tags", tags, indentLevel)

func addKeyFeature(result: var string; val: KeyFeature; indentLevel = 1) =
  ## Appends the pretty-printed JSON for an `key_feature` object with value `val` to
  ## `result`.
  result.addNewlineAndIndent(indentLevel)
  result.add "{"
  result.addString("icon", val.icon, indentLevel + 1)
  result.addString("title", val.title, indentLevel + 1)
  result.addString("content", val.content, indentLevel + 1)
  result.removeComma()
  result.addNewlineAndIndent(indentLevel)
  result.add "},"

func addKeyFeatures(result: var string; val: KeyFeatures; indentLevel = 1) =
  ## Appends the pretty-printed JSON for an `key_features` key with value `val` to
  ## `result`.
  result.addNewlineAndIndent(indentLevel)
  escapeJson("key_features", result)
  result.add ": ["
  for keyFeature in val:
    result.addKeyFeature(keyFeature, indentLevel + 1)
  result.removeComma()
  result.addNewlineAndIndent(indentLevel)
  result.add "],"

func addConcept(result: var string; val: Concept; indentLevel = 1) =
  ## Appends the pretty-printed JSON for a `concept` object with value `val` to
  ## `result`.
  result.addNewlineAndIndent(indentLevel)
  result.add "{"
  result.addString("uuid", val.uuid, indentLevel + 1)
  result.addString("slug", val.slug, indentLevel + 1)
  result.addString("name", val.name, indentLevel + 1)
  result.removeComma()
  result.addNewlineAndIndent(indentLevel)
  result.add "},"

func addConceptExercise(result: var string; val: ConceptExercise;
    indentLevel = 1) =
  ## Appends the pretty-printed JSON for a `concept` object with value `val` to
  ## `result`.
  result.addNewlineAndIndent(indentLevel)
  result.add "{"
  result.addString("slug", $val.slug, indentLevel + 1)
  result.addString("name", val.name, indentLevel + 1)
  result.addString("uuid", val.uuid, indentLevel + 1)
  if val.concepts.len > 0:
    result.addArray("concepts", toSeq(val.concepts), indentLevel + 1)
  if val.prerequisites.len > 0:
    result.addArray("prerequisites", toSeq(val.prerequisites), indentLevel + 1)
  if val.status != sMissing:
    result.addString("status", $val.status, indentLevel + 1)
  result.removeComma()
  result.addNewlineAndIndent(indentLevel)
  result.add "},"

func addConceptExercises(result: var string; val: seq[ConceptExercise];
    indentLevel = 2) =
  ## Appends the pretty-printed JSON for a `concepts` key with value `val` to
  ## `result`.
  result.addNewlineAndIndent(indentLevel)
  escapeJson("concept", result)
  result.add ": ["
  for exercise in val:
    result.addConceptExercise(exercise, indentLevel + 1)
  result.removeComma()
  result.addNewlineAndIndent(indentLevel)
  result.add "],"

func addPracticeExercise(result: var string; val: PracticeExercise;
    indentLevel = 1) =
  ## Appends the pretty-printed JSON for a `practice` object with value `val` to
  ## `result`.
  result.addNewlineAndIndent(indentLevel)
  result.add "{"
  result.addString("slug", $val.slug, indentLevel + 1)
  result.addString("name", val.name, indentLevel + 1)
  result.addString("uuid", val.uuid, indentLevel + 1)
  if val.practices.len > 0:
    result.addArray("practices", toSeq(val.practices), indentLevel + 1)
  if val.prerequisites.len > 0:
    result.addArray("prerequisites", toSeq(val.prerequisites), indentLevel + 1)
  result.addInt("difficulty", val.difficulty, indentLevel + 1)
  if val.status != sMissing:
    result.addString("status", $val.status, indentLevel + 1)
  if val.topics.isSome() and val.topics.get.len > 0:
    result.addArray("topics", toSeq(val.topics.get), indentLevel + 1)
  result.removeComma()
  result.addNewlineAndIndent(indentLevel)
  result.add "},"

func addPracticeExercises(result: var string; val: seq[PracticeExercise];
    indentLevel = 2) =
  ## Appends the pretty-printed JSON for a `practice` key with value `val` to
  ## `result`.
  result.addNewlineAndIndent(indentLevel)
  escapeJson("practice", result)
  result.add ": ["
  for exercise in val:
    result.addPracticeExercise(exercise, indentLevel + 1)
  result.removeComma()
  result.addNewlineAndIndent(indentLevel)
  result.add "],"

func addExercises(result: var string; val: Exercises; indentLevel = 1) =
  ## Appends the pretty-printed JSON for a `concepts` key with value `val` to
  ## `result`.
  result.addNewlineAndIndent(indentLevel)
  escapeJson("exercises", result)
  result.add ": {"
  if val.`concept`.len > 0:
    result.addConceptExercises(val.`concept`, indentLevel + 1)
  if val.practice.len > 0:
    result.addPracticeExercises(val.practice, indentLevel + 1)
  if val.foregone.len > 0:
    result.addArray("foregone", toSeq(val.foregone), indentLevel + 1)
  result.removeComma()
  result.addNewlineAndIndent(indentLevel)
  result.add "},"

func addConcepts(result: var string; val: Concepts; indentLevel = 1) =
  ## Appends the pretty-printed JSON for a `concepts` key with value `val` to
  ## `result`.
  result.addNewlineAndIndent(indentLevel)
  escapeJson("concepts", result)
  result.add ": ["
  for `concept` in val:
    result.addConcept(`concept`, indentLevel + 1)
  result.removeComma()
  result.addNewlineAndIndent(indentLevel)
  result.add "],"

func prettyTrackConfig(e: TrackConfig): string =
  ## Serializes `e` as pretty-printed JSON, using the canonical key order.
  let keys = trackConfigKeyOrderForFmt(e)

  result = newStringOfCap(2000)
  result.add '{'
  for key in keys:
    case key
    of tckLanguage:
      result.addString("language", e.language)
    of tckSlug:
      result.addString("slug", e.slug)
    of tckBlurb:
      result.addString("blurb", e.blurb)
    of tckActive:
      result.addBool("active", e.active)
    of tckVersion:
      result.addInt("version", e.version)
    of tckExercises:
      result.addExercises(e.exercises)
    of tckFiles:
      result.addFiles(e.files)
    of tckConcepts:
      result.addConcepts(e.concepts)
    of tckOnlineEditor:
      result.addOnlineEditor(e.onlineEditor)
    of tckKeyFeatures:
      result.addKeyFeatures(e.keyFeatures)
    of tckTestRunner:
      result.addTestRunner(e.testRunner)
    of tckStatus:
      result.addStatus(e.status)
    of tckTags:
      result.addTags(e.tags)
  result.removeComma()
  result.add "\n}\n"

proc formatTrackConfigFile*(configPath: string): string =
  ## Parses the `config.json` file at `configPath` and returns it in the
  ## canonical form.
  let trackConfig = TrackConfig.init configPath.readFile()
  prettyTrackConfig(trackConfig)
