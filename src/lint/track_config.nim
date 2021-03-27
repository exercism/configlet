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

proc isValidTag(data: JsonNode, context: string, path: string): bool =
  result = true

  if data.kind == JString:
    let s = data.getStr()
    if not tags.contains(s):
      result.setFalseAndPrint("Not a valid tag: " & $data, path)
  else:
    result.setFalseAndPrint("Tag is not a string: " & $data, path)

proc hasValidStatus(data: JsonNode, path: string): bool =
  if hasObject(data, "status", path):
    result = true
    let d = data["status"]

    if not checkBoolean(d, "concept_exercises", path):
      result = false
    if not checkBoolean(d, "test_runner", path):
      result = false
    if not checkBoolean(d, "representer", path):
      result = false
    if not checkBoolean(d, "analyzer", path):
      result = false

proc hasValidOnlineEditor(data: JsonNode, path: string): bool =
  if hasObject(data, "online_editor", path):
    result = true
    let d = data["online_editor"]
    const indentStyles = ["space", "tab"].toHashSet()

    if not checkString(d, "indent_style", path, allowed = indentStyles):
      result = false
    if not checkInteger(d, "indent_size", path, allowed = 0..8):
      result = false

proc isValidKeyFeature(data: JsonNode, context: string, path: string): bool =
  if isObject(data, context, path):
    result = true

    # TODO: Enable the `icon` checks when we have a list of valid icons.
    if false:
      const icons = [
        "todo",
      ].toHashSet()

      if not checkString(data, "icon", path, allowed = icons):
        result = false

    if not checkString(data, "title", path, maxLen = 25):
      result = false
    if not checkString(data, "content", path, maxLen = 100):
      result = false

proc hasValidKeyFeatures(data: JsonNode, path: string): bool =
  result = hasArrayOf(data, "key_features", path, isValidKeyFeature,
                      isRequired = false, allowedLength = 6..6)

proc isValidTrackConfig(data: JsonNode, path: string): bool =
  if isObject(data, "", path):
    result = true

    if not checkString(data, "language", path):
      result = false
    if not checkString(data, "slug", path):
      result = false
    if not checkBoolean(data, "active", path):
      result = false
    if not checkString(data, "blurb", path, maxLen = 400):
      result = false
    if not checkInteger(data, "version", path, allowed = 3..3):
      result = false

    if not hasValidStatus(data, path):
      result = false
    if not hasValidOnlineEditor(data, path):
      result = false
    if not hasValidKeyFeatures(data, path):
      result = false

    if not hasArrayOf(data, "tags", path, isValidTag):
      result = false

proc isTrackConfigValid*(trackDir: string): bool =
  result = true
  let trackConfigPath = trackDir / "config.json"
  let j = parseJsonFile(trackConfigPath, result)
  if j != nil:
    if not isValidTrackConfig(j, trackConfigPath):
      result = false
