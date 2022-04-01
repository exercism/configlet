import std/logging
import "."/cli

func levelThreshold(verbosity: Verbosity): Level =
  case verbosity
  of verQuiet: lvlNone
  of verNormal: lvlNotice
  of verDetailed: lvlInfo

proc setupLogging*(conf: Conf) =
  let consoleLogger = newConsoleLogger(levelThreshold = levelThreshold(conf.verbosity),
                                       fmtStr = "")
  addHandler(consoleLogger)

template logNormal*(msgs: varargs[string]) =
  notice(msgs)

template logDetailed*(msgs: varargs[string]) =
  info(msgs)
