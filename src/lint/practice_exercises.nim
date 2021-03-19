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
    if not hasArrayOfStrings(data, context, "solution", path):
      result = false
    if not hasArrayOfStrings(data, context, "test", path):
      result = false
    if not hasArrayOfStrings(data, context, "example", path):
      result = false
  else:
    result = false

proc isValidPracticeExerciseConfig(data: JsonNode, path: string): bool =
  if isObject(data, "", path):
    result = true
    # Temporarily disable the checking of authors as we'll be doing bulk PRs
    # to pre-populate this field for all tracks
    # if not hasArrayOf(data, "authors", path, isValidAuthorOrContributor):
    #   result = false
    if not hasArrayOf(data, "contributors", path, isValidAuthorOrContributor,
                      isRequired = false):
      result = false
    # Temporarily disable the checking of the files to give tracks the chance
    # to update this manually
    # if not checkFiles(data, "files", path):
    #   result = false
    if not checkString(data, "language_versions", path, isRequired = false):
      result = false

proc isEveryPracticeExerciseConfigValid*(trackDir: string): bool =
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

proc practiceExerciseFilesExist*(trackDir: string): bool =
  ## Returns true if every subdirectory in `trackDir/exercises/practice` has the
  ## required files.
  const
    requiredPracticeExerciseFiles = [
      ".docs" / "instructions.md",
      ".meta" / "config.json",
    ]

  let practiceExercisesDir = trackDir / "exercises" / "practice"
  result = subdirsContain(practiceExercisesDir, requiredPracticeExerciseFiles)
