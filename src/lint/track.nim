import std/[json, os, terminal]
import ".."/[helpers]

proc isTrackConfigValid*(trackDir: string): bool =
  result = true
  let configJsonPath = trackDir / "config.json"
  if fileExists(configJsonPath):
    try:
      let j = parseFile(configJsonPath)
    except:
      writeError("JSON parsing error", getCurrentExceptionMsg())
  else:
    writeError("Missing file", configJsonPath)
