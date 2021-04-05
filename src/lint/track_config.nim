import std/[json, os, sets]
import ".."/helpers
import "."/validators

const tags = [
  "paradigm/declarative",
  "paradigm/functional",
  "paradigm/imperative",
  "paradigm/logic",
  "paradigm/object_oriented",
  "paradigm/procedural",
  "typing/static",
  "typing/dynamic",
  "typing/strong",
  "typing/weak",
  "execution_mode/compiled",
  "execution_mode/interpreted",
  "platform/windows",
  "platform/mac",
  "platform/linux",
  "platform/ios",
  "platform/android",
  "platform/web",
  "runtime/standalone_executable",
  "runtime/language_specific",
  "runtime/clr",
  "runtime/jvm",
  "runtime/beam",
  "runtime/wasmtime",
  "used_for/artificial_intelligence",
  "used_for/backends",
  "used_for/cross_platform_development",
  "used_for/embedded_systems",
  "used_for/financial_systems",
  "used_for/frontends",
  "used_for/games",
  "used_for/guis",
  "used_for/mobile",
  "used_for/robotics",
  "used_for/scientific_calculations",
  "used_for/scripts",
  "used_for/web_development",
].toHashSet()

proc hasValidTags(data: JsonNode; path: Path): bool =
  result = hasArrayOfStrings(data, "", "tags", path, allowed = tags)

proc hasValidStatus(data: JsonNode; path: Path): bool =
  if hasObject(data, "status", path):
    let d = data["status"]
    let checks = [
      hasBoolean(d, "concept_exercises", path),
      hasBoolean(d, "test_runner", path),
      hasBoolean(d, "representer", path),
      hasBoolean(d, "analyzer", path),
    ]
    result = allTrue(checks)

proc hasValidOnlineEditor(data: JsonNode; path: Path): bool =
  if hasObject(data, "online_editor", path):
    let d = data["online_editor"]
    const indentStyles = ["space", "tab"].toHashSet()
    let checks = [
      hasString(d, "indent_style", path, allowed = indentStyles),
      hasInteger(d, "indent_size", path, allowed = 0..8),
    ]
    result = allTrue(checks)

const
  statuses = ["wip", "beta", "active", "deprecated"].toHashSet()

proc isValidConceptExercise(data: JsonNode; context: string; path: Path): bool =
  if isObject(data, context, path):
    let checks = [
      hasString(data, "slug", path),
      hasString(data, "name", path),
      hasString(data, "uuid", path),
      hasBoolean(data, "deprecated", path, isRequired = false),
      hasArrayOfStrings(data, "", "concepts", path),
      hasArrayOfStrings(data, "", "prerequisites", path),
      hasString(data, "status", path, isRequired = false, allowed = statuses),
    ]
    result = allTrue(checks)

proc isValidPracticeExercise(data: JsonNode; context: string;
                             path: Path): bool =
  if isObject(data, context, path):
    let checks = [
      hasString(data, "slug", path),
      hasString(data, "name", path),
      hasString(data, "uuid", path),
      hasBoolean(data, "deprecated", path, isRequired = false),
      hasInteger(data, "difficulty", path, allowed = 0..10),
      hasArrayOfStrings(data, "", "practices", path,
                        allowedArrayLen = 0..int.high),
      hasArrayOfStrings(data, "", "prerequisites", path,
                        allowedArrayLen = 0..int.high),
      hasString(data, "status", path, isRequired = false, allowed = statuses),
    ]
    result = allTrue(checks)

proc hasValidExercises(data: JsonNode; path: Path): bool =
  if hasObject(data, "exercises", path):
    let exercises = data["exercises"]
    let checks = [
      hasArrayOf(exercises, "concept", path, isValidConceptExercise,
                 allowedLength = 0..int.high),
      hasArrayOf(exercises, "practice", path, isValidPracticeExercise,
                 allowedLength = 0..int.high),
      hasArrayOfStrings(exercises, "", "foregone", path, isRequired = false),
    ]
    result = allTrue(checks)

proc isValidConcept(data: JsonNode; context: string; path: Path): bool =
  if isObject(data, context, path):
    let checks = [
      hasString(data, "uuid", path),
      hasString(data, "slug", path),
      hasString(data, "name", path),
    ]
    result = allTrue(checks)

proc hasValidConcepts(data: JsonNode; path: Path): bool =
  result = hasArrayOf(data, "concepts", path, isValidConcept,
                      allowedLength = 0..int.high)

proc isValidKeyFeature(data: JsonNode; context: string; path: Path): bool =
  if isObject(data, context, path):
    const icons = [
      "todo",
    ].toHashSet()
    # TODO: Enable the `icon` checks when we have a list of valid icons.
    let checks = [
      if false: hasString(data, "icon", path, allowed = icons) else: true,
      hasString(data, "title", path, maxLen = 25),
      hasString(data, "content", path, maxLen = 100),
    ]
    result = allTrue(checks)

proc hasValidKeyFeatures(data: JsonNode; path: Path): bool =
  result = hasArrayOf(data, "key_features", path, isValidKeyFeature,
                      isRequired = false, allowedLength = 6..6)

proc isValidTrackConfig(data: JsonNode; path: Path): bool =
  if isObject(data, "", path):
    let checks = [
      hasString(data, "language", path),
      hasString(data, "slug", path),
      hasBoolean(data, "active", path),
      hasString(data, "blurb", path, maxLen = 400),
      hasInteger(data, "version", path, allowed = 3..3),
      hasValidStatus(data, path),
      hasValidOnlineEditor(data, path),
      hasValidExercises(data, path),
      hasValidConcepts(data, path),
      hasValidKeyFeatures(data, path),
      hasValidTags(data, path),
    ]
    result = allTrue(checks)

proc isTrackConfigValid*(trackDir: Path): bool =
  result = true
  let trackConfigPath = trackDir / "config.json"
  let j = parseJsonFile(trackConfigPath, result)
  if j != nil:
    if not isValidTrackConfig(j, trackConfigPath):
      result = false
