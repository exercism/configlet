import options, os, parseopt, strformat, strutils

type
  Action* {.pure.} = enum
    sync, check, help, version

  Mode* {.pure.} = enum
    choose, includeMissing, excludeMissing

  Verbosity* {.pure.} = enum
    quiet, normal, detailed

  Arguments* = object
    action*: Action
    exercise*: Option[string]
    mode*: Mode
    verbosity*: Verbosity

  Argument = tuple[short: string, long: string]

const NimblePkgVersion {.strdefine}: string = "unknown"

const ExerciseArgument  : Argument = (short: "e", long: "exercise")
const CheckArgument     : Argument = (short: "c", long: "check")
const ModeArgument      : Argument = (short: "m", long: "mode")
const VerbosityArgument : Argument = (short: "o", long: "verbosity")
const HelpArgument      : Argument = (short: "h", long: "help")
const VersionArgument   : Argument = (short: "v", long: "version")

proc showHelp*: void =
  let applicationName = extractFileName(getAppFilename())

  echo &"""Usage: {applicationName} [options]
  
Options:
  -{ExerciseArgument.short}, --{ExerciseArgument.long} <slug>        Only sync this exercise
  -{CheckArgument.short}, --{CheckArgument.long}                  Check if there missing tests. Doesn't update the tests
  -{ModeArgument.short}, --{ModeArgument.long} <mode>            What to do with missing test cases. Allowed values: choose, include, exclude
  -{VerbosityArgument.short}, --{VerbosityArgument.long} <verbosity>  The verbosity of output. Allowed values: quiet, normal, detailed
  -{HelpArgument.short}, --{HelpArgument.long}                   Show CLI usage
  -{VersionArgument.short}, --{VersionArgument.long}                Display version information"""

proc showVersion*: void = 
  echo &"Canonical Data Syncer v{NimblePkgVersion}"

proc parseArguments*: Arguments =
  result.action = Action.sync
  result.verbosity = Verbosity.normal

  var optParser = initOptParser()
  for kind, key, val in optParser.getopt():
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of ExerciseArgument.short, ExerciseArgument.long:
        result.exercise = some(val)
      of CheckArgument.short, CheckArgument.long:
        result.action = check
      of ModeArgument.short, ModeArgument.long:
        result.mode = parseEnum[Mode](val, Mode.choose)
      of VerbosityArgument.short, VerbosityArgument.long:
        result.verbosity = parseEnum[Verbosity](val, Verbosity.normal)
      of HelpArgument.short, HelpArgument.long:
        result.action = help
      of VersionArgument.short, VersionArgument.long:
        result.action = version
    else: 
      discard
