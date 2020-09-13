import strformat
import options, commands/[check,format,update]

const NimblePkgVersion {.strdefine}: string = "unknown"

echo &"Exercism Canonical Data Syncer v{NimblePkgVersion}"

let opts = parseOptions()

case opts.command
of Command.check:
  check()
of Command.update:
  update()
of Command.format:
  format()
