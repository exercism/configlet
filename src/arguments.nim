import options, os, parseopt, sequtils, strformat, strutils

type
  Action* {.pure.} = enum
    unknown, check, update, help, version

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

  echo &"Usage: {applicationName} [options]"
  echo ""
  echo "Options:"
  echo &"  -{ExerciseArgument.short}, --{ExerciseArgument.long} <slug>  Only sync this exercise"
  echo &"  -{CheckArgument.short}, --{CheckArgument.long}            Check if there are exercises with missing test cases"
  echo &"  -{HelpArgument.short}, --{HelpArgument.long}             Show CLI usage" 
  echo &"  -{VersionArgument.short}, --{VersionArgument.long}          Display version information"

proc showVersion*() = 
  echo &"Canonical Data Syncer v{NimblePkgVersion}"

proc parseArguments*: Arguments =
  result.action = Action.update

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
        of CheckArgument.short, CheckArgument.long:
          result.action = check
        of HelpArgument.short, HelpArgument.long:
          result.action = help
        of VersionArgument.short, VersionArgument.long:
          result.action = version
      of cmdEnd: 
        result.action = unknown
  except ValueError:
    result.action = unknown
