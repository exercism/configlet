import std/[json, os]
import ".."/helpers
import "."/validators

proc hasValidRepresenter(data: JsonNode; path: Path): bool =
  const s = "representer"
  if data.hasKey(s):
    if hasObject(data, s, path):
      result = hasInteger(data[s], "version", path, s, isRequired = true, allowed = 1..int.high)

proc hasValidFiles(data: JsonNode; path, exerciseDir: Path): bool =
  const k = "files"
  if hasObject(data, k, path):
    let d = data[k]
    let checks = [
      hasArrayOfFiles(d, "solution", path, k, exerciseDir),
      hasArrayOfFiles(d, "test", path, k, exerciseDir),
      hasArrayOfFiles(d, "exemplar", path, k, exerciseDir),
      hasArrayOfFiles(d, "editor", path, k, exerciseDir, isRequired = false),
      hasArrayOfFiles(d, "invalidator", path, k, exerciseDir, isRequired = false),
    ]
    result = allTrue(checks)

proc isValidConceptExerciseConfig(data: JsonNode;
                                  path, exerciseDir: Path): bool =
  if isObject(data, jsonRoot, path):
    let checks = [
      hasString(data, "blurb", path, maxLen = 350),
      hasString(data, "source", path, isRequired = false),
      hasString(data, "source_url", path, isRequired = false,
                checkIsUrlLike = true),
      hasArrayOfStrings(data, "authors", path, uniqueValues = true),
      hasArrayOfStrings(data, "contributors", path, isRequired = false,
                        uniqueValues = true),
      hasValidFiles(data, path, exerciseDir),
      hasArrayOfStrings(data, "forked_from", path, isRequired = false,
                        uniqueValues = true),
      hasString(data, "language_versions", path, isRequired = false),
      hasValidRepresenter(data, path),
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
        if not isValidConceptExerciseConfig(j, configPath, exerciseDir):
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
