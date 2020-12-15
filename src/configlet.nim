import std/[posix]
import "."/[cli, logger, sync/check, sync/sync]

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
