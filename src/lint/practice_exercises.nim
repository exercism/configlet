import std/[json, os]
import ".."/helpers
import "."/validators

proc checkFiles(data: JsonNode, context, path: string): bool =
  if hasObject(data, context, path):
    result = true
    if not hasArrayOfStrings(data, context, "solution", path):
      result = false
    if not hasArrayOfStrings(data, context, "test", path):
      result = false
    if not hasArrayOfStrings(data, context, "example", path):
      result = false

proc isValidPracticeExerciseConfig(data: JsonNode, path: string): bool =
  if isObject(data, "", path):
    result = true
    if not hasArrayOfStrings(data, "", "authors", path, isRequired = false):
      result = false
    if not hasArrayOfStrings(data, "", "contributors", path, isRequired = false):
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

proc practiceExerciseDocsExist*(trackDir: string): bool =
  ## Returns true if every subdirectory in `trackDir/exercises/practice` has the
  ## required Markdown files.
  const
    requiredPracticeExerciseDocs = [
      ".docs" / "instructions.md",
    ]

  let practiceExercisesDir = trackDir / "exercises" / "practice"
  result = subdirsContain(practiceExercisesDir, requiredPracticeExerciseDocs)
