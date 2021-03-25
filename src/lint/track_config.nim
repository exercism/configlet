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

    if checkString(d, "indent_style", path):
      let s = d["indent_style"].getStr()
      if s != "space" and s != "tab":
        let msg = "The value of `online_editor.indent_style` is `" & s &
                  "`, but it must be `space` or `tab`"
        result.setFalseAndPrint(msg, path)
    else:
      result = false

    if checkInteger(d, "indent_size", path):
      let num = d["indent_size"].getInt()
      if num < 0:
        let msg = "The value of `online_editor.indent_size` is `" & $num &
                  "`, but it must be an integer >= 0"
        result.setFalseAndPrint(msg, path)
    else:
      result = false

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

    if checkInteger(data, "version", path):
      let version = data["version"].getInt()
      if version != 3:
        let msg = "The value of `version` is `" & $version &
                  "`, but it must be the integer `3`"
        result.setFalseAndPrint(msg, path)
    else:
      result = false

    if not hasValidStatus(data, path):
      result = false
    if not hasValidOnlineEditor(data, path):
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
