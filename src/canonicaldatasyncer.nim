import strformat
import arguments, commands/[check,update]

const NimblePkgVersion {.strdefine}: string = "unknown"

echo &"Exercism Canonical Data Syncer v{NimblePkgVersion}"

let args = parseArguments()

case args.command
of Command.check:
  check(args)
of Command.update:
  update(args)
