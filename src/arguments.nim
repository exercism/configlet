import std/[options, os, parseopt, strformat, strutils]

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
const DefaultArgument   : Argument = (short: "d", long: "default")
const VerbosityArgument : Argument = (short: "o", long: "verbosity")
const HelpArgument      : Argument = (short: "h", long: "help")
const VersionArgument   : Argument = (short: "v", long: "version")

proc showHelp*: void =
  let applicationName = extractFileName(getAppFilename())

  echo &"""Usage: {applicationName} [options]
  
Options:
  -{ExerciseArgument.short}, --{ExerciseArgument.long} <slug>        Only sync this exercise
  -{CheckArgument.short}, --{CheckArgument.long}                  Check if there missing tests. Doesn't update the tests
  -{DefaultArgument.short}, --{DefaultArgument.long} <mode>            What to do with missing test cases. Allowed values: c[hoose], i[nclude], e[xclude]
  -{VerbosityArgument.short}, --{VerbosityArgument.long} <verbosity>  The verbosity of output. Allowed values: q[uiet], n[ormal], d[etailed]
  -{HelpArgument.short}, --{HelpArgument.long}                   Show CLI usage
  -{VersionArgument.short}, --{VersionArgument.long}                Display version information"""

proc showVersion*: void = 
  echo &"Canonical Data Syncer v{NimblePkgVersion}"

proc parseMode(mode: string): Mode =
  case mode.toLowerAscii
  of "c", "choose": Mode.choose
  of "i", "include": Mode.includeMissing
  of "e", "exclude": Mode.excludeMissing
  else: Mode.choose

proc parseVerbosity(verbosity: string): Verbosity =
  case verbosity.toLowerAscii
  of "q", "quiet": Verbosity.quiet
  of "n", "normal": Verbosity.normal
  of "d", "detailed": Verbosity.detailed
  else: Verbosity.normal

proc parseArguments*: Arguments =
  result.action = Action.sync
  result.verbosity = Verbosity.normal
  result.mode = Mode.choose

  var optParser = initOptParser()
  for kind, key, val in optParser.getopt():
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of ExerciseArgument.short, ExerciseArgument.long:
        result.exercise = some(val)
      of CheckArgument.short, CheckArgument.long:
        result.action = check
      of DefaultArgument.short, DefaultArgument.long:
        result.mode = parseMode(val)
      of VerbosityArgument.short, VerbosityArgument.long:
        result.verbosity = parseVerbosity(val)
      of HelpArgument.short, HelpArgument.long:
        result.action = help
      of VersionArgument.short, VersionArgument.long:
        result.action = version
    else: 
      discard
