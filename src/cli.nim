import std/[options, os, parseopt, strformat, strutils]

type
  Action* = enum
    actSync, actCheck

  Mode* = enum
    modeChoose, modeIncludeMissing, modeExcludeMissing

  Verbosity* = enum
    verQuiet, verNormal, verDetailed

  Arguments* = object
    action*: Action
    exercise*: Option[string]
    mode*: Mode
    verbosity*: Verbosity

  Argument = tuple[short: string, long: string]

const NimblePkgVersion {.strdefine.}: string = "unknown"

const ExerciseArgument  : Argument = (short: "e", long: "exercise")
const CheckArgument     : Argument = (short: "c", long: "check")
const ModeArgument      : Argument = (short: "m", long: "mode")
const VerbosityArgument : Argument = (short: "o", long: "verbosity")
const HelpArgument      : Argument = (short: "h", long: "help")
const VersionArgument   : Argument = (short: "v", long: "version")

proc showHelp =
  let applicationName = extractFilename(getAppFilename())

  echo &"""Usage: {applicationName} [options]

Options:
  -{ExerciseArgument.short}, --{ExerciseArgument.long} <slug>        Only sync this exercise
  -{CheckArgument.short}, --{CheckArgument.long}                  Check if there are missing tests. Doesn't update the tests. Terminates with a non-zero exit code if one or more tests are missing
  -{ModeArgument.short}, --{ModeArgument.long} <mode>            What to do with missing test cases. Allowed values: c[hoose], i[nclude], e[xclude]
  -{VerbosityArgument.short}, --{VerbosityArgument.long} <verbosity>  The verbosity of output. Allowed values: q[uiet], n[ormal], d[etailed]
  -{HelpArgument.short}, --{HelpArgument.long}                   Show this help message and exit
  -{VersionArgument.short}, --{VersionArgument.long}                Show this tool's version information and exit"""

  quit(0)

proc showVersion =
  echo &"Canonical Data Syncer v{NimblePkgVersion}"
  quit(0)

proc parseMode(mode: string): Mode =
  case mode.toLowerAscii
  of "c", "choose": modeChoose
  of "i", "include": modeIncludeMissing
  of "e", "exclude": modeExcludeMissing
  else: modeChoose

proc parseVerbosity(verbosity: string): Verbosity =
  case verbosity.toLowerAscii
  of "q", "quiet": verQuiet
  of "n", "normal": verNormal
  of "d", "detailed": verDetailed
  else: verNormal

proc initArguments: Arguments =
  result = Arguments(
    action: actSync,
    exercise: none(string),
    mode: modeChoose,
    verbosity: verNormal,
  )

proc parseArguments*: Arguments =
  result = initArguments()

  for kind, key, val in getopt():
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of ExerciseArgument.short, ExerciseArgument.long:
        result.exercise = some(val)
      of CheckArgument.short, CheckArgument.long:
        result.action = actCheck
      of ModeArgument.short, ModeArgument.long:
        result.mode = parseMode(val)
      of VerbosityArgument.short, VerbosityArgument.long:
        result.verbosity = parseVerbosity(val)
      of HelpArgument.short, HelpArgument.long:
        showHelp()
      of VersionArgument.short, VersionArgument.long:
        showVersion()
    else:
      discard
