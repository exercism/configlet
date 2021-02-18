import std/[json, os, terminal]
import ".."/helpers
import "."/validators

proc isValidTrackConfig(data: JsonNode, path: string): bool =
  if isObject(data, "root", path):
    result = true
    checkString("language")
    checkString("slug")
    checkString("blurb")
    checkBoolean("active")
    checkInteger("version")
    
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
