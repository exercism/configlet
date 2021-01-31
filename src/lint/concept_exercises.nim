import std/[json, os, terminal]
import ".."/helpers
import "."/validators

proc isValidAuthorOrContributor(data: JsonNode, key: string, path: string): bool =
  result = true
  checkObject("")
  checkString("github_username")
  checkString("exercism_username")

template checkFiles(data: JsonNode, context, path: string) =
  checkObject(context)
  checkArrayOfStrings(context, "solution")
  checkArrayOfStrings(context, "test")
  checkArrayOfStrings(context, "exemplar")

proc isValidConceptExerciseConfig(data: JsonNode, path: string): bool =
  result = true
  checkObject("")
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
