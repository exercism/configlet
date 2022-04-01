import std/logging
import "."/cli

func levelThreshold(verbosity: Verbosity): Level =
  case verbosity
  of verQuiet: lvlNone
  of verNormal: lvlNotice
  of verDetailed: lvlInfo

proc setupLogging*(verbosity: Verbosity) =
  let consoleLogger = newConsoleLogger(levelThreshold = levelThreshold(verbosity),
                                       fmtStr = "")
  addHandler(consoleLogger)

template logNormal*(msgs: varargs[string]) =
  notice(msgs)

template logDetailed*(msgs: varargs[string]) =
  info(msgs)
