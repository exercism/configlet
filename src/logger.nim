import std/[logging]
import "."/[cli]

func levelThreshold(verbosity: Verbosity): Level =
  case verbosity
  of verQuiet: lvlNone
  of verNormal: lvlNotice
  of verDetailed: lvlInfo

proc setupLogging*(conf: Conf) =
  let consoleLogger = newConsoleLogger(levelThreshold = levelThreshold(conf.verbosity), fmtStr = "")
  addHandler(consoleLogger)

proc logNormal*(conf: varargs[string]) =
  notice(conf)

proc logDetailed*(conf: varargs[string]) =
  info(conf)
