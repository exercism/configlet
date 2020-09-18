import arguments, check, errorhandling, logger, sync

handleExitSignal()

let args = parseArguments()

setupLogging(args)

case args.action
of Action.sync:
  sync(args)
of Action.check:
  check(args)
of Action.help:
  showHelp()
of Action.version:
  showVersion()
