import std/posix
import "."/[cli, completion/completion, create/create, fmt/fmt, info/info,
            generate/generate, lint/lint, logger, sync/sync, uuid/uuid]

proc configlet =
  onSignal(SIGTERM):
    quit QuitSuccess

  let conf = processCmdLine()

  setupLogging(conf.verbosity)

  case conf.action.kind
  of actNil:
    discard
  of actCompletion:
    completion(conf.action.shell)
  of actCreate:
    create(conf)
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

proc main =
  try:
    configlet()
  except CatchableError:
    let msg = getCurrentExceptionMsg()
    showError(msg)

when isMainModule:
  main()
