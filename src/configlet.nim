import std/posix
import "."/[cli, completion/completion, fmt/fmt, info/info, generate/generate,
            lint/lint, logger, sync/sync, uuid/uuid]

proc main =
  onSignal(SIGTERM):
    quit(0)

  let conf = processCmdLine()

  setupLogging(conf.verbosity)

  case conf.action.kind
  of actNil:
    discard
  of actCompletion:
    completion(conf.action.shell)
  of actFmt:
    fmt(conf)
  of actLint:
    lint(conf)
  of actSync:
    sync(conf)
  of actUuid:
    uuid(conf.action.num)
  of actGenerate:
    generate(conf)
  of actInfo:
    info(conf)

main()
