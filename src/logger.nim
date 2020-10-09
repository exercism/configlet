import std/logging
import arguments

proc levelThreshold(verbosity: Verbosity): Level =
  case verbosity
  of verQuiet: lvlNone
  of verNormal: lvlNotice
  of verDetailed: lvlInfo

proc setupLogging*(args: Arguments) =
  let consoleLogger = newConsoleLogger(levelThreshold = levelThreshold(args.verbosity), fmtStr = "")
  addHandler(consoleLogger)

proc logNormal*(args: varargs[string]) =
  notice(args)

proc logDetailed*(args: varargs[string]) =
  info(args)
