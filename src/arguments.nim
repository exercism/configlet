import options, os, parseopt, sequtils, strformat, strutils

type
  Command* = enum
    check, update

  LogLevel* = enum
    quiet, normal, detailed

  Arguments* = object
    command*: Command
    logLevel*: LogLevel
    exercise*: Option[string]

  Argument = tuple[short: string, long: string]

const NimblePkgVersion {.strdefine}: string = "unknown"

const ExerciseArgument: Argument = (short: "e", long: "exercise")
const LogLevelArgument: Argument = (short: "l", long: "loglevel")
const HelpArgument    : Argument = (short: "h", long: "help")
const VersionArgument : Argument = (short: "v", long: "version")

proc showHelp() =
  let commandOptions = toSeq(Command).join("|")
  let verbosityOptions = toSeq(LogLevel).mapIt(&"[{($it)[0]}]{($it)[1..^1]}").join("|")
  let applicationName = extractFileName(getAppFilename())

  echo &"Usage: {applicationName} [options] {{{commandOptions}}}"
  echo ""
  echo "Options:"
  echo &"  -{ExerciseArgument.short}, --{ExerciseArgument.long} <slug>       Check/update only this exercise"
  echo &"  -{LogLevelArgument.short}, --{LogLevelArgument.long} <verbosity>  Set the log level: {verbosityOptions}"
  echo &"  -{HelpArgument.short}, --{HelpArgument.long}                  Show CLI usage" 
  echo &"  -{VersionArgument.short}, --{VersionArgument.long}               Display version information"

proc showVersion() = 
  echo &"Canonical Data Syncer v{NimblePkgVersion}"

proc handleFailure: void =
  showHelp()
  quit(QuitFailure)

proc parseArguments*: Arguments =
  var command: Option[string]
  var exercise: Option[string]
  var logLevel: Option[string]

  var optParser = initOptParser()
  for kind, key, val in optParser.getopt():
    case kind
    of cmdArgument:
       command = some(key)
       break
    of cmdLongOption, cmdShortOption:
      case key
      of ExerciseArgument.short, ExerciseArgument.long:
        exercise = some(key)
      of LogLevelArgument.short, LogLevelArgument.long:
        logLevel = some(key)
      of HelpArgument.short, HelpArgument.long:
        showHelp()
        quit(QuitSuccess)
      of VersionArgument.short, VersionArgument.long:
        showVersion()
        quit(QuitSuccess)
    of cmdEnd: 
      handleFailure()

  if command.isNone:
    handleFailure()

  try:
    result.command = parseEnum[Command](command.get)
    result.logLevel = parseEnum[LogLevel](logLevel.get($LogLevel.normal))
    result.exercise = exercise
  except ValueError:
    handleFailure()
