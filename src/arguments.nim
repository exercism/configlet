import options, os, parseopt, sequtils, strformat, strutils

type
  Command {.pure.} = enum
    check, update

  Action* {.pure.} = enum
    unknown, check, update, help, version

  LogLevel* = enum
    quiet, normal, detailed

  Arguments* = object
    action*: Action
    logLevel*: LogLevel
    exercise*: Option[string]

  Argument = tuple[short: string, long: string]

const NimblePkgVersion {.strdefine}: string = "unknown"

const ExerciseArgument: Argument = (short: "e", long: "exercise")
const LogLevelArgument: Argument = (short: "l", long: "loglevel")
const HelpArgument    : Argument = (short: "h", long: "help")
const VersionArgument : Argument = (short: "v", long: "version")

proc showHelp*() =
  let commandOptions = toSeq(Command).join("|")
  let verbosityOptions = toSeq(LogLevel).mapIt(&"[{($it)[0]}]{($it)[1..^1]}").join("|")
  let applicationName = extractFileName(getAppFilename())

  echo &"Usage: {applicationName} [options] [{commandOptions}]"
  echo ""
  echo "Options:"
  echo &"  -{ExerciseArgument.short}, --{ExerciseArgument.long} <slug>       Check/update only this exercise"
  echo &"  -{LogLevelArgument.short}, --{LogLevelArgument.long} <verbosity>  Set the log level: {verbosityOptions}"
  echo &"  -{HelpArgument.short}, --{HelpArgument.long}                  Show CLI usage" 
  echo &"  -{VersionArgument.short}, --{VersionArgument.long}               Display version information"

proc showVersion*() = 
  echo &"Canonical Data Syncer v{NimblePkgVersion}"

proc parseArguments*: Arguments =
  result.action = Action.check
  result.logLevel = LogLevel.normal

  try:
    var optParser = initOptParser()
    for kind, key, val in optParser.getopt():
      case kind
      of cmdArgument:
        result.action = parseEnum[Action](key)
        break
      of cmdLongOption, cmdShortOption:
        case key
        of ExerciseArgument.short, ExerciseArgument.long:
          result.exercise = some(key)
        of LogLevelArgument.short, LogLevelArgument.long:
          result.logLevel = parseEnum[LogLevel](key)
        of HelpArgument.short, HelpArgument.long:
          result.action = help
        of VersionArgument.short, VersionArgument.long:
          result.action = version
      of cmdEnd: 
        result.action = unknown
  except ValueError:
    result.action = unknown
