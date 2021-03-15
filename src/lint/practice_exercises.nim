import std/os
import "."/validators

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
