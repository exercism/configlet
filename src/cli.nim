import std/[options, os, parseopt, strformat, strutils, terminal]

type
  Action* = enum
    actSync, actCheck

  Mode* = enum
    modeChoose, modeIncludeMissing, modeExcludeMissing

  Verbosity* = enum
    verQuiet, verNormal, verDetailed

  Conf* = object
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

proc showError(s: string) =
  stdout.styledWrite(fgRed, "Error: ")
  stdout.write(s)
  stdout.write("\n\n")
  showHelp()

proc prefix(kind: CmdLineKind): string =
  case kind
  of cmdShortOption: "-"
  of cmdLongOption: "--"
  of cmdArgument, cmdEnd: ""

proc showErrorForMissingVal(kind: CmdLineKind, key: string, val: string) =
  if val.len == 0:
    let msg = &"'{kind.prefix}{key}' was given without a value"
    showError(msg)

proc parseMode(kind: CmdLineKind, key: string, val: string): Mode =
  case val.toLowerAscii
  of "c", "choose":
    result = modeChoose
  of "i", "include":
    result = modeIncludeMissing
  of "e", "exclude":
    result = modeExcludeMissing
  else:
    showError(&"invalid value for '{kind.prefix}{key}': '{val}'")

proc parseVerbosity(kind: CmdLineKind, key: string, val: string): Verbosity =
  case val.toLowerAscii
  of "q", "quiet":
    result = verQuiet
  of "n", "normal":
    result = verNormal
  of "d", "detailed":
    result = verDetailed
  else:
    showError(&"invalid value for '{kind.prefix}{key}': '{val}'")

proc initConf: Conf =
  result = Conf(
    action: actSync,
    exercise: none(string),
    mode: modeChoose,
    verbosity: verNormal,
  )

proc processCmdLine*: Conf =
  result = initConf()

  for kind, key, val in getopt():
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of ExerciseArgument.short, ExerciseArgument.long:
        showErrorForMissingVal(kind, key, val)
        result.exercise = some(val)
      of CheckArgument.short, CheckArgument.long:
        result.action = actCheck
      of ModeArgument.short, ModeArgument.long:
        showErrorForMissingVal(kind, key, val)
        result.mode = parseMode(kind, key, val)
      of VerbosityArgument.short, VerbosityArgument.long:
        showErrorForMissingVal(kind, key, val)
        result.verbosity = parseVerbosity(kind, key, val)
      of HelpArgument.short, HelpArgument.long:
        showHelp()
      of VersionArgument.short, VersionArgument.long:
        showVersion()
      else:
        showError(&"invalid option: '{kind.prefix}{key}'")
    of cmdArgument:
      case key.toLowerAscii
      of HelpArgument.long:
        showHelp()
      else:
        showError(&"invalid argument: '{key}'")
    of cmdEnd:
      discard
