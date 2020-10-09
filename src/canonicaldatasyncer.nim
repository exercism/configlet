import std/posix
import arguments, check, logger, sync

proc main =
  onSignal(SIGTERM):
    quit(0)

  let args = parseArguments()

  setupLogging(args)

  case args.action
  of actSync:
    sync(args)
  of actCheck:
    check(args)
  of actHelp:
    showHelp()
  of actVersion:
    showVersion()

main()
