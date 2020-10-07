import std/logging
import arguments

proc levelThreshold(verbosity: Verbosity): Level =
  case verbosity
  of Verbosity.quiet: lvlNone
  of Verbosity.normal: lvlNotice
  of Verbosity.detailed: lvlInfo

proc setupLogging*(args: Arguments): void =
  let consoleLogger = newConsoleLogger(levelThreshold=levelThreshold(args.verbosity), fmtStr="")
  addHandler(consoleLogger)

proc logNormal*(args: varargs[string]): void = 
  notice(args)

proc logDetailed*(args: varargs[string]): void = 
  info(args)
