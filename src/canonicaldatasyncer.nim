import arguments, commands/[check,update]

let args = parseArguments()

case args.action
of Action.check:
  check(args)
of Action.update:
  update(args)
of Action.help:
  showHelp()
of Action.version:
  showVersion()
