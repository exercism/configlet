import std/[json, os, terminal]
import ".."/helpers
import "."/validators

let tags = @[
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
  "used_for/web_development"
]

proc isValidTag(data: JsonNode, context: string, path: string): bool =
  if data.kind == JString:
    let s = data.getStr()
    for tag in tags:
      if s == tag:
        result = true

    if not result:
      writeError("Not a valid tag: " & $data, path)
  else:
      writeError("Tag is not a string: " & $data, path)

proc isValidTrackConfig(data: JsonNode, path: string): bool =
  if isObject(data, "root", path):
    result = true
    checkString("language")
    checkString("slug")
    checkString("blurb")
    checkBoolean("active")
    checkInteger("version")
    checkArrayOf("tags", isValidTag)
    
proc isTrackConfigValid*(trackDir: string): bool =
  result = true
  let configJsonPath = trackDir / "config.json"
  if fileExists(configJsonPath):
    let j = 
      try:
        parseFile(configJsonPath)
      except:
        writeError("JSON parsing error", getCurrentExceptionMsg())
        return
    if not isValidTrackConfig(j, configJsonPath):
        result = false
  else:
    writeError("Missing file", configJsonPath)
