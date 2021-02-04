import std/[json, os, terminal]
import ".."/helpers
import "."/validators

proc isValidAuthorOrContributor(data: JsonNode, key: string, path: string): bool =
  if isObject(data, "", path):
    result = true
    checkString("github_username")
    checkString("exercism_username", isRequired = false)

template checkFiles(data: JsonNode, context, path: string) =
  if isObject(data, context, path):
    checkArrayOfStrings(context, "solution")
    checkArrayOfStrings(context, "test")
    checkArrayOfStrings(context, "exemplar")
  else:
    result = false

proc isValidConceptExerciseConfig(data: JsonNode, path: string): bool =
  if isObject(data, "", path):
    result = true
    checkArrayOf("authors", isValidAuthorOrContributor)
    checkArrayOf("contributors", isValidAuthorOrContributor, isRequired = false)
    checkFiles(data, "files", path)
    checkArrayOfStrings("", "forked_from", isRequired = false)
    checkString("language_versions", isRequired = false)

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
            writeError("JSON parsing error", getCurrentExceptionMsg())
            continue
        if not isValidConceptExerciseConfig(j, configPath):
          result = false
