import std/posix
import arguments, check, logger, sync

proc main =
  onSignal(SIGTERM):
    quit(0)

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

main()
