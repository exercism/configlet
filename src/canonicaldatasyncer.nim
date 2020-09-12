import strformat, syncer

const NimblePkgVersion {.strdefine}: string = "unknown"

echo &"Exercism Canonical Data Syncer v{NimblePkgVersion}"

syncTests()
