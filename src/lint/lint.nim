import std/[json, os, strformat, terminal]
import ".."/[cli, helpers]

template writeError(description: string, details: string) =
  stdout.styledWriteLine(fgRed, description & ":")
  stdout.writeLine(details)
  stdout.write "\n"
  result = false

proc isValidTrackConfig(trackDir: string): bool =
  result = true
  let configJsonPath = trackDir / "config.json"
  if fileExists(configJsonPath):
    try:
      let j = parseFile(configJsonPath)
    except:
      writeError("JSON parsing error", getCurrentExceptionMsg())
  else:
    writeError("Missing file", configJsonPath)

proc conceptExerciseFilesExist(trackDir: string): bool =
  const
    conceptExerciseFiles = [
      ".docs" / "hints.md",
      ".docs" / "instructions.md",
      ".docs" / "introduction.md",
      ".meta" / "config.json",
    ]

  let conceptDir = trackDir / "exercises" / "concept"
  result = true

  if dirExists(conceptDir):
    for dir in getSortedSubDirs(conceptDir):
      for conceptExerciseFile in conceptExerciseFiles:
        let path = dir / conceptExerciseFile
        if not fileExists(path):
          writeError("Missing file", path)

proc lint*(conf: Conf) =
  echo "The lint command is under development.\n"  &
       "Please re-run this command regularly to see if your track passes " &
       "the latest linting rules.\n"

  let trackDir = conf.trackDir
  let b1 = isValidTrackConfig(trackDir)
  let b2 = conceptExerciseFilesExist(trackDir)

  if b1 and b2:
    echo """
Basic linting finished successfully:
- config.json exists and is valid JSON
- Every concept exercise has the required .md files and a .meta/config.json file"""
  else:
    quit(1)
