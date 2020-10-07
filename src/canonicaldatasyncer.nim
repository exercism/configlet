import std/posix
import arguments, check, logger, sync

proc main =
  onSignal(SIGTERM):
    quit(0)

  let args = parseArguments()

  setupLogging(args)

  case args.action
  of Action.Sync:
    sync(args)
  of Action.Check:
    check(args)
  of Action.Help:
    showHelp()
  of Action.Version:
    showVersion()

main()
