import strformat
import os
import commands
import sequtils

type
  ProbSpecsExercise* = object
    slug*: string
    dir*: string
    canonicalDataJsonFile*: string

let probSpecsDir = joinPath(getCurrentDir(), ".problem-specifications")

proc cloneProbSpecsRepo*: void =
  let cmd = &"git clone --depth 1 https://github.com/exercism/problem-specifications.git {probSpecsDir}"
  execCmdException(cmd, IOError, "Could not clone problem-specifications repo")

  # TODO: remove once the uuids branch is merged in prob-specs
  execCmdException("git checkout --track origin/uuids", IOError, "Could not checkout the uuids branch")

proc removeProbSpecsRepo*: void =
  removeDir(probSpecsDir)

proc probSpecExerciseFromDir(dir: string): ProbSpecsExercise =
  ProbSpecsExercise(
    slug: extractFilename(dir),
    dir: dir,
    canonicalDataJsonFile: joinPath(dir, "canonical-data.json"),
  )

proc findProbSpecExercises*: seq[ProbSpecsExercise] =
  toSeq(walkDirs(joinPath(probSpecsDir, "exercises/*"))).map(probSpecExerciseFromDir)
