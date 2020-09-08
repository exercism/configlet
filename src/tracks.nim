import sequtils, os

type
  TrackExercise* = object
    slug*: string
    dir*: string
    dataJsonFile*: string
    customJsonFile*: string
    testsTomlFile*: string

proc trackExerciseFromDir(dir: string): TrackExercise =
  TrackExercise(
    slug: extractFilename(dir),
    dir: dir,
    dataJsonFile: joinPath(joinPath(dir, ".data"), "data.json"),
    customJsonFile: joinPath(joinPath(dir, ".data"), "custom.json"),
    testsTomlFile: joinPath(joinPath(dir, ".data"), "tests.toml")
  )

proc findTrackExercises*: seq[TrackExercise] =
  toSeq(walkDirs("exercises/*")).map(trackExerciseFromDir)
