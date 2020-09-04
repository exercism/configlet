import strformat
import parsetoml
import json
import osproc
import os

const NimblePkgVersion {.strdefine}: string = "unknown"

let probSpecsDir = joinPath(getCurrentDir(), ".problem-specifications")

proc cloneProbSpecsRepo =
  # TODO: handle errors
  discard execCmd(fmt"git clone --depth 1 https://github.com/exercism/problem-specifications.git {probSpecsDir}")

proc removeProbSpecsRepo =
  removeDir(probSpecsDir)

proc main =
  echo fmt"Exercism Canonical Data Syncer v{NimblePkgVersion}"

  try:
    removeProbSpecsRepo()
    cloneProbSpecsRepo()

  finally:
    removeProbSpecsRepo()

  # let table1 = parsetoml.parseFile("tests.toml")

  # let x = "hi"
  # var y = 2

  # echo x
  # echo y

  # echo table1.toJson.pretty()

main()