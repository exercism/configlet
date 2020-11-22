import std/posix
import check, cli, logger, sync

proc main =
  onSignal(SIGTERM):
    quit(0)

  let conf = processCmdLine()

  setupLogging(conf)

  case conf.action.kind
  of actNil:
    discard
  of actSync:
    if conf.action.check:
      check(conf)
    else:
      sync(conf)

main()
