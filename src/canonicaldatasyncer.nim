import os, strutils, strformat, syncer

const NimblePkgVersion {.strdefine}: string = "unknown"

let describeUsage = &"Usage: {extractFileName(getAppFilename())} [check|update]"

echo &"Exercism Canonical Data Syncer v{NimblePkgVersion}"

if paramCount() == 0:
    quit(describeUsage)

case paramStr(1)
of "check":
  echo "check"
  syncTests()
of "update":
  echo "update"
else:
  echo &"Invalid option: {paramStr(1)}"
  quit(describeUsage)