import options, os, parseopt, strformat

type
  Action* {.pure.} = enum
    sync, check, help, version

  Arguments* = object
    action*: Action
    check*: bool
    exercise*: Option[string]

  Argument = tuple[short: string, long: string]

const NimblePkgVersion {.strdefine}: string = "unknown"

const ExerciseArgument: Argument = (short: "e", long: "exercise")
const CheckArgument   : Argument = (short: "c", long: "check")
const HelpArgument    : Argument = (short: "h", long: "help")
const VersionArgument : Argument = (short: "v", long: "version")

proc showHelp*() =
  let applicationName = extractFileName(getAppFilename())

  echo &"""Usage: {applicationName} [options]
  
Options:
  -{ExerciseArgument.short}, --{ExerciseArgument.long} <slug>  Only sync this exercise
  -{CheckArgument.short}, --{CheckArgument.long}            Check if there are exercises with missing test cases
  -{HelpArgument.short}, --{HelpArgument.long}             Show CLI usage
  -{VersionArgument.short}, --{VersionArgument.long}          Display version information"""

proc showVersion*() = 
  echo &"Canonical Data Syncer v{NimblePkgVersion}"

proc parseArguments*: Arguments =
  result.action = Action.sync

  var optParser = initOptParser()
  for kind, key, val in optParser.getopt():
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of ExerciseArgument.short, ExerciseArgument.long:
        result.exercise = some(key)
      of CheckArgument.short, CheckArgument.long:
        result.action = check
      of HelpArgument.short, HelpArgument.long:
        result.action = help
      of VersionArgument.short, VersionArgument.long:
        result.action = version
    else: 
      discard
