import strformat
import sequtils
import parsetoml
import json
import osproc
import os

type
  Exercise = object
    slug: string
    dir: string
    dataDir: string
    dataJsonFile: string
    customJsonFile: string
    testsTomlFile: string

const NimblePkgVersion {.strdefine}: string = "unknown"

let probSpecsDir = joinPath(getCurrentDir(), ".problem-specifications")

proc execCmdException(cmd: string, exceptn: typedesc, message: string): void =
  if execCmd(cmd) != 0:
    raise newException(exceptn, message)

proc cloneProbSpecsRepo: void =
  let cmd = &"git clone --depth 1 https://github.com/exercism/problem-specifications.git {probSpecsDir}"
  execCmdException(cmd, IOError, "Could not clone problem-specifications repo")

  # TODO: remove once the uuids branch is merged in prob-specs
  execCmdException("git checkout --track origin/uuids", IOError, "Could not checkout the uuids branch")

proc removeProbSpecsRepo: void =
  removeDir(probSpecsDir)

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

proc findExercises: seq[Exercise] =
  toSeq(walkDirs("exercises/*")).map(exerciseFromDir)

proc syncExerciseData(exercise: Exercise): void =
  if not fileExists(exercise.testsTomlFile):
    # echo &"Syncing {exercise.slug} (skipped)"
    return
  
  # echo &"Syncing {exercise.slug}"
  let tests = parsetoml.parseFile(exercise.testsTomlFile)
  echo tests["canonical-tests"].toJson.pretty()
  for k, v in tests["canonical-tests"].getTable().pairs:
    echo &"Found elem: {k},{v}" 

proc syncExercisesData: void =
  for exercise in findExercises():
      syncExerciseData(exercise)

proc main: void =
  echo &"Exercism Canonical Data Syncer v{NimblePkgVersion}"

  try:
    # removeProbSpecsRepo()
    # cloneProbSpecsRepo()
    syncExercisesData()
  except:
    echo fmt"Error: {getCurrentExceptionMsg()}"
  # finally:
  #   removeProbSpecsRepo() 

main()