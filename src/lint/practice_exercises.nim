import std/[json, os]
import ".."/helpers
import "."/validators

proc hasValidRepresenter(data: JsonNode; path: Path): bool =
  const k = "representer"
  if data.hasKey(k):
    if hasObject(data, k, path):
      result = hasInteger(data[k], "version", path, k, isRequired = true,
                          allowed = 1..1000)
  else:
    result = true

proc hasValidFiles(data: JsonNode; path, exerciseDir: Path): bool =
  const k = "files"
  if hasObject(data, k, path):
    let d = data[k]
    let checks = [
      hasArrayOfFiles(d, "solution", path, k, exerciseDir),
      hasArrayOfFiles(d, "test", path, k, exerciseDir),
      hasArrayOfFiles(d, "example", path, k, exerciseDir),
      hasArrayOfFiles(d, "editor", path, k, exerciseDir, isRequired = false),
      hasArrayOfFiles(d, "invalidator", path, k, exerciseDir, isRequired = false),
    ]
    result = allTrue(checks)

proc isValidPracticeExerciseConfig(data: JsonNode;
                                   path, exerciseDir: Path): bool =
  if isObject(data, jsonRoot, path):
    let checks = [
      hasString(data, "blurb", path, maxLen = 350),
      hasString(data, "source", path, isRequired = false),
      hasString(data, "source_url", path, isRequired = false,
                checkIsUrlLike = true),
      hasArrayOfStrings(data, "authors", path, isRequired = false,
                        uniqueValues = true),
      hasArrayOfStrings(data, "contributors", path, isRequired = false,
                        uniqueValues = true),
      hasValidFiles(data, path, exerciseDir),
      hasString(data, "language_versions", path, isRequired = false),
      hasBoolean(data, "test_runner", path, isRequired = false),
      hasValidRepresenter(data, path),
      hasString(data, "icon", path, isRequired = false, checkIsKebab = true),
    ]
    result = allTrue(checks)

proc isEveryPracticeExerciseConfigValid*(trackDir: Path): bool =
  let practiceExercisesDir = trackDir / "exercises" / "practice"
  result = true
  # Return true even if the directory does not exist - this allows a future
  # track to have concept exercises and no practice exercises.
  if dirExists(practiceExercisesDir):
    for exerciseDir in getSortedSubdirs(practiceExercisesDir):
      let configPath = exerciseDir / ".meta" / "config.json"
      let j = parseJsonFile(configPath, result)
      if j != nil:
        if not isValidPracticeExerciseConfig(j, configPath, exerciseDir):
          result = false

proc practiceExerciseDocsExist*(trackDir: Path): bool =
  ## Returns true if every subdirectory in `trackDir/exercises/practice` has the
  ## required Markdown files.
  const
    requiredPracticeExerciseDocs = [
      ".docs" / "instructions.md",
    ]

  let practiceExercisesDir = trackDir / "exercises" / "practice"
  result = subdirsContain(practiceExercisesDir, requiredPracticeExerciseDocs)
