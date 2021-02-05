import std/[json, os, terminal]
import ".."/[cli, helpers]
import "."/concept_exercises

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

proc subdirsContain(dir: string, files: openArray[string]): bool =
  ## Returns `true` if every file in `files` exists in every subdirectory of
  ## `dir`.
  ##
  ## Returns `true` if `dir` does not exist or has no subdirectories.
  result = true

  if dirExists(dir):
    for subdir in getSortedSubdirs(dir):
      for file in files:
        let path = subdir / file
        if not fileExists(path):
          writeError("Missing file", path)

proc conceptExerciseFilesExist(trackDir: string): bool =
  ## Returns true if every subdirectory in `trackDir/exercises/concept` has the
  ## required files.
  const
    conceptExerciseFiles = [
      ".docs" / "hints.md",
      ".docs" / "instructions.md",
      ".docs" / "introduction.md",
      ".meta" / "config.json",
    ]

  let conceptDir = trackDir / "exercises" / "concept"
  result = subdirsContain(conceptDir, conceptExerciseFiles)

proc conceptFilesExist(trackDir: string): bool =
  ## Returns true if every subdirectory in `trackDir/concepts` has the required
  ## files.
  const
    conceptFiles = [
      "about.md",
      "introduction.md",
      "links.json",
    ]

  let conceptsDir = trackDir / "concepts"
  result = subdirsContain(conceptsDir, conceptFiles)

proc lint*(conf: Conf) =
  echo "The lint command is under development.\n" &
       "Please re-run this command regularly to see if your track passes " &
       "the latest linting rules.\n"

  let trackDir = conf.trackDir
  let b1 = isValidTrackConfig(trackDir)
  let b2 = conceptExerciseFilesExist(trackDir)
  let b3 = conceptFilesExist(trackDir)
  let b4 = isEveryConceptExerciseConfigValid(trackDir)

  if b1 and b2 and b3 and b4:
    echo """
Basic linting finished successfully:
- config.json exists and is valid JSON
- Every concept has the required .md files and links.json file
- Every concept exercise has the required .md files and a .meta/config.json file
- Every concept exercise .meta/config.json file is valid"""
  else:
    quit(1)
