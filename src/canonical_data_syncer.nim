import std/posix
import check, cli, logger, sync

proc main =
  onSignal(SIGTERM):
    quit(0)

  let conf = processCmdLine()

  setupLogging(conf)

  if conf.check:
    check(conf)
  else:
    sync(conf)

main()
