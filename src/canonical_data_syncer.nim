import strformat
import parsetoml
import json

const NimblePkgVersion {.strdefine}: string = "unknown"

proc main() =
  echo fmt"Exercism Canonical Data Syncer v{NimblePkgVersion}"

  let table1 = parsetoml.parseFile("tests.toml")

  let x = "hi"
  var y = 2

  echo x
  echo y

  echo table1.toJson.pretty()

main()