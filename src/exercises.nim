import sequtils
import os

type
  Exercise* = object
    slug*: string
    dir*: string
    dataDir*: string
    dataJsonFile*: string
    customJsonFile*: string
    testsTomlFile*: string

proc exerciseFromDir(dir: string): Exercise =
  let slug = extractFilename(dir)
  let dataDir = joinPath(dir, ".data")
  let dataJsonFile = joinPath(dataDir, "data.json")
  let customJsonFile = joinPath(dataDir, "custom.json")
  let testsTomlFile = joinPath(dataDir, "tests.toml")

  Exercise(
    slug: slug,
    dir: dir,
    dataDir: dataDir,
    dataJsonFile: dataJsonFile,
    customJsonFile: customJsonFile,
    testsTomlFile: testsTomlFile
  )

proc findExercises*: seq[Exercise] =
  toSeq(walkDirs("exercises/*")).map(exerciseFromDir)
