import std/[json, os]
import ".."/helpers
import "."/validators

proc checkFiles(data: JsonNode, context, path: string): bool =
  if hasObject(data, context, path):
    let checks = [
      hasArrayOfStrings(data, context, "solution", path),
      hasArrayOfStrings(data, context, "test", path),
      hasArrayOfStrings(data, context, "exemplar", path),
    ]
    result = allTrue(checks)

proc isValidConceptExerciseConfig(data: JsonNode, path: string): bool =
  if isObject(data, "", path):
    let checks = [
      checkString(data, "blurb", path, maxLen = 350),
      hasArrayOfStrings(data, "", "authors", path),
      hasArrayOfStrings(data, "", "contributors", path, isRequired = false),
      checkFiles(data, "files", path),
      hasArrayOfStrings(data, "", "forked_from", path, isRequired = false),
      checkString(data, "language_versions", path, isRequired = false),
    ]
    result = allTrue(checks)

proc isEveryConceptExerciseConfigValid*(trackDir: string): bool =
  let conceptExercisesDir = trackDir / "exercises" / "concept"
  result = true
  if dirExists(conceptExercisesDir):
    for exerciseDir in getSortedSubdirs(conceptExercisesDir):
      let configPath = exerciseDir / ".meta" / "config.json"
      let j = parseJsonFile(configPath, result)
      if j != nil:
        if not isValidConceptExerciseConfig(j, configPath):
          result = false

proc conceptExerciseDocsExist*(trackDir: string): bool =
  ## Returns true if every subdirectory in `trackDir/exercises/concept` has the
  ## required Markdown files.
  const
    requiredConceptExerciseDocs = [
      ".docs" / "hints.md",
      ".docs" / "instructions.md",
      ".docs" / "introduction.md",
    ]

  let conceptExercisesDir = trackDir / "exercises" / "concept"
  result = subdirsContain(conceptExercisesDir, requiredConceptExerciseDocs)
