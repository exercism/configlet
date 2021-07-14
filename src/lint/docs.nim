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
  result = subdirContains(sharedExerciseDocsDir, requiredSharedExerciseDocs)

proc trackDocsExist*(trackDir: Path): bool =
  ## Returns true if the `trackDir/docs` directory has the required files.
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
  result = subdirContains(docsDir, requiredTrackDocs)
