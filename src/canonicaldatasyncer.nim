import options, strformat

const NimblePkgVersion {.strdefine}: string = "unknown"

echo &"Exercism Canonical Data Syncer v{NimblePkgVersion}"

let opts = parseOptions()

case opts.command
of Command.check:
  echo "Check check"
of Command.update:
  echo "Update"
of Command.format:
  echo "Format"