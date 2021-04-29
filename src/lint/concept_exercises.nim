import std/[json, os]
import ".."/helpers
import "."/validators

proc hasValidFiles(data: JsonNode, path: Path): bool =
  const k = "files"
  if hasObject(data, k, path):
    let d = data[k]
    let checks = [
      hasArrayOfStrings(d, "solution", path, k),
      hasArrayOfStrings(d, "test", path, k),
      hasArrayOfStrings(d, "exemplar", path, k),
    ]
    result = allTrue(checks)

proc isValidConceptExerciseConfig(data: JsonNode, path: Path): bool =
  if isObject(data, "", path):
    let checks = [
      hasString(data, "blurb", path, maxLen = 350),
      hasArrayOfStrings(data, "authors", path),
      hasArrayOfStrings(data, "contributors", path, isRequired = false),
      hasValidFiles(data, path),
      hasArrayOfStrings(data, "forked_from", path, isRequired = false),
      hasString(data, "language_versions", path, isRequired = false),
      hasString(data, "icon", path, isRequired = false, checkIsKebab = true),
    ]
    result = allTrue(checks)

proc isEveryConceptExerciseConfigValid*(trackDir: Path): bool =
  let conceptExercisesDir = trackDir / "exercises" / "concept"
  result = true
  if dirExists(conceptExercisesDir):
    for exerciseDir in getSortedSubdirs(conceptExercisesDir):
      let configPath = exerciseDir / ".meta" / "config.json"
      let j = parseJsonFile(configPath, result)
      if j != nil:
        if not isValidConceptExerciseConfig(j, configPath):
          result = false

proc conceptExerciseDocsExist*(trackDir: Path): bool =
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
