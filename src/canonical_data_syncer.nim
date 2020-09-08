import strformat
import parsetoml
import json
import osproc
import os

const NimblePkgVersion {.strdefine}: string = "unknown"

let probSpecsDir = joinPath(getCurrentDir(), ".problem-specifications")

proc execCmdException(cmd: string, exceptn: typedesc, message: string) =
  if execCmd(cmd) != 0:
    raise newException(exceptn, message)

proc cloneProbSpecsRepo =
  let cmd = fmt"git clone --depth 1 https://github.com/exercism/problem-specifications.git {probSpecsDir}"
  execCmdException(cmd, IOError, "Could not clone problem-specifications repo")

  # TODO: remove once the uuids branch is merged in prob-specs
  execCmdException("git checkout --track origin/uuids", IOError, "Could not checkout the uuids branch")

proc removeProbSpecsRepo =
  removeDir(probSpecsDir)

proc main =
  echo fmt"Exercism Canonical Data Syncer v{NimblePkgVersion}"

  try:
    removeProbSpecsRepo()
    cloneProbSpecsRepo()
  except:
    echo fmt"Error: {getCurrentExceptionMsg()}"
  finally:
    removeProbSpecsRepo()

  # let table1 = parsetoml.parseFile("tests.toml")

  # let x = "hi"
  # var y = 2

  # echo x
  # echo y

  # echo table1.toJson.pretty()

main()