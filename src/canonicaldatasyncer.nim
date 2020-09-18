import arguments, check, errorhandling, sync

setupInterruptHandler()

case args.action
of Action.sync:
  sync(args)
of Action.check:
  check(args)
of Action.help:
  showHelp()
of Action.version:
  showVersion()
