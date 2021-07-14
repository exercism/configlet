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
