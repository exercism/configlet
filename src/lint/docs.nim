import std/json
import ".."/helpers
import "."/validators

proc sharedExerciseDocsExist*(trackDir: Path): bool =
  ## Returns true if the `trackDir/exercises/shared/.docs` directory has the
  ## required Markdown files.
  const
    requiredSharedExerciseDocs = [
      "help.md",
      "tests.md",
    ]

  let sharedExerciseDocsDir = trackDir / "exercises" / "shared" / ".docs"
  result = dirContains(sharedExerciseDocsDir, requiredSharedExerciseDocs)

proc isActiveTrack(trackDir: Path): bool =
  ## Returns true if the track-level `config.json` file has `"active": true`.
  ##
  ## Returns false if that file is missing or is not valid JSON. We don't print
  ## anything in that case, because `isTrackConfigValid` reports those problems.
  let trackConfigPath = trackDir / "config.json"
  if fileExists(trackConfigPath):
    try:
      let j = parseJson(readFile(trackConfigPath))
      result = j.kind == JObject and j{"active"}.getBool()
    except CatchableError:
      result = false

proc trackDocsExist*(trackDir: Path): bool =
  ## Returns true if the `trackDir/docs` directory has the required files.
  ##
  ## An active track must also have a `docs/SIGN_UP_SNIPPET.txt` file, which
  ## the website shows during sign-up.
  const
    requiredTrackDocs = [
      "ABOUT.md",
      "INSTALLATION.md",
      "LEARNING.md",
      "RESOURCES.md",
      "SNIPPET.txt",
      "TESTS.md",
    ]

  let docsDir = trackDir / "docs"
  result = dirContains(docsDir, requiredTrackDocs)

  # Check the active-only file separately, so that a missing `docs` directory
  # is reported only once.
  if dirExists(docsDir) and isActiveTrack(trackDir):
    if not dirContains(docsDir, ["SIGN_UP_SNIPPET.txt"]):
      result = false
