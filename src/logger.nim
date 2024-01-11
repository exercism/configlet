import std/logging
import "."/cli

let consoleLogger = newConsoleLogger(levelThreshold = lvlNotice,
                                     fmtStr = "")

func toLevel(verbosity: Verbosity): Level =
  case verbosity
  of verQuiet: lvlNone
  of verNormal: lvlNotice
  of verDetailed: lvlInfo

proc setLevel(verbosity: Verbosity) =
  consoleLogger.levelThreshold = toLevel(verbosity)

proc setupLogging*(verbosity: Verbosity) =
  addHandler(consoleLogger)
  setLevel(verbosity)

template withLevel*(verbosity: Verbosity, body: untyped): untyped =
  let currentLevel = consoleLogger.levelThreshold
  consoleLogger.levelThreshold = toLevel(verbosity)
  body
  consoleLogger.levelThreshold = currentLevel

template logNormal*(msgs: varargs[string]) =
  notice(msgs)

template logDetailed*(msgs: varargs[string]) =
  info(msgs)
