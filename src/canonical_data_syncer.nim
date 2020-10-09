import std/posix
import check, cli, logger, sync

proc main =
  onSignal(SIGTERM):
    quit(0)

  let conf = processCmdLine()

  setupLogging(conf)

  case conf.action
  of actSync:
    sync(conf)
  of actCheck:
    check(conf)

main()
