import std/[json, os]
import ".."/helpers
import "."/validators

proc hasValidFiles(data: JsonNode, path: Path): bool =
  const context = "files"
  if hasObject(data, context, path):
    let d = data[context]
    let checks = [
      hasArrayOfStrings(d, context, "solution", path),
      hasArrayOfStrings(d, context, "test", path),
      hasArrayOfStrings(d, context, "example", path),
    ]
    result = allTrue(checks)

proc isValidPracticeExerciseConfig(data: JsonNode, path: Path): bool =
  if isObject(data, "", path):
    # TODO: Enable the `files` checks after the tracks have had some time to update.
    let checks = [
      hasString(data, "blurb", path, maxLen = 350),
      hasArrayOfStrings(data, "", "authors", path, isRequired = false),
      hasArrayOfStrings(data, "", "contributors", path, isRequired = false),
      if false: hasValidFiles(data, path) else: true,
      hasString(data, "language_versions", path, isRequired = false),
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
        if not isValidPracticeExerciseConfig(j, configPath):
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
