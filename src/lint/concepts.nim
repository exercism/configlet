import std/os
import "."/validators

proc conceptFilesExist*(trackDir: string): bool =
  ## Returns true if every subdirectory in `trackDir/concepts` has the required
  ## files.
  const
    requiredConceptFiles = [
      "about.md",
      "introduction.md",
      "links.json",
    ]

  let conceptsDir = trackDir / "concepts"
  result = subdirsContain(conceptsDir, requiredConceptFiles)
