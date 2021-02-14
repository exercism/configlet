import std/posix
import "."/[cli, info/info, generate/generate, lint/lint, logger, sync/check,
            sync/update, uuid/uuid]

proc main =
  onSignal(SIGTERM):
    quit(0)

  let conf = processCmdLine()

  setupLogging(conf)

  case conf.action.kind
  of actNil:
    discard
  of actLint:
    lint(conf)
  of actSync:
    if conf.action.update:
      update(conf)
    else:
      check(conf)
  of actUuid:
    uuid(conf.action.num)
  of actGenerate:
    generate(conf)
  of actInfo:
    info(conf)

main()
