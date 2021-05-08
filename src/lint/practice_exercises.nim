import std/[json, os]
import ".."/helpers
import "."/validators

proc hasValidFiles(data: JsonNode; path, exerciseDir: Path): bool =
  const k = "files"
  if hasObject(data, k, path):
    let d = data[k]
    let checks = [
      hasArrayOfFiles(d, "solution", path, k, exerciseDir),
      hasArrayOfFiles(d, "test", path, k, exerciseDir),
      hasArrayOfFiles(d, "example", path, k, exerciseDir),
    ]
    result = allTrue(checks)

proc isValidPracticeExerciseConfig(data: JsonNode;
                                   path, exerciseDir: Path): bool =
  if isObject(data, "", path):
    # TODO: Enable the `files` checks after the tracks have had some time to update.
    let checks = [
      hasString(data, "blurb", path, maxLen = 350),
      hasArrayOfStrings(data, "authors", path, isRequired = false,
                        uniqueValues = true),
      hasArrayOfStrings(data, "contributors", path, isRequired = false,
                        uniqueValues = true),
      hasValidFiles(data, path, exerciseDir),
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
