import std/[json, os]
import ".."/helpers
import "."/validators

proc isValidAuthorOrContributor(data: JsonNode, context: string, path: string): bool =
  if isObject(data, context, path):
    result = true
    if not checkString(data, "github_username", path):
      result = false
    if not checkString(data, "exercism_username", path, isRequired = false):
      result = false

proc checkFiles(data: JsonNode, context, path: string): bool =
  result = true
  if hasObject(data, context, path):
    if not checkArrayOfStrings(data, context, "solution", path):
      result = false
    if not checkArrayOfStrings(data, context, "test", path):
      result = false
    if not checkArrayOfStrings(data, context, "exemplar", path):
      result = false
  else:
    result = false

proc isValidConceptExerciseConfig(data: JsonNode, path: string): bool =
  if isObject(data, "", path):
    result = true
    if not hasArrayOf(data, "authors", path, isValidAuthorOrContributor):
      result = false
    if not hasArrayOf(data, "contributors", path, isValidAuthorOrContributor,
                      isRequired = false):
      result = false
    if not checkFiles(data, "files", path):
      result = false
    if not checkArrayOfStrings(data, "", "forked_from", path, isRequired = false):
      result = false
    if not checkString(data, "language_versions", path, isRequired = false):
      result = false

proc isEveryConceptExerciseConfigValid*(trackDir: string): bool =
  let conceptExercisesDir = trackDir / "exercises" / "concept"
  result = true
  if dirExists(conceptExercisesDir):
    for exerciseDir in getSortedSubdirs(conceptExercisesDir):
      let configPath = exerciseDir / ".meta" / "config.json"
      if fileExists(configPath):
        let j =
          try:
            parseFile(configPath)
          except:
            result.setFalseAndPrint("JSON parsing error", getCurrentExceptionMsg())
            continue
        if not isValidConceptExerciseConfig(j, configPath):
          result = false

proc conceptExerciseFilesExist*(trackDir: string): bool =
  ## Returns true if every subdirectory in `trackDir/exercises/concept` has the
  ## required files.
  const
    requiredConceptExerciseFiles = [
      ".docs" / "hints.md",
      ".docs" / "instructions.md",
      ".docs" / "introduction.md",
      ".meta" / "config.json",
    ]

  let conceptExercisesDir = trackDir / "exercises" / "concept"
  result = subdirsContain(conceptExercisesDir, requiredConceptExerciseFiles)
