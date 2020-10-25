import std/[options, os, strformat, strutils, terminal]
import pkg/[cligen/parseopt3]

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
    probSpecsDir*: Option[string]
    offline*: bool

  Opt = enum
    optExercise, optCheck, optMode, optVerbosity, optProbSpecsDir, optOffline,
    optHelp, optVersion

  OptKey = tuple
    short: string
    long: string

const
  NimblePkgVersion {.strdefine.}: string = "unknown"

  optKeys: array[Opt, OptKey] = [
    ("e", "exercise"),
    ("c", "check"),
    ("m", "mode"),
    ("v", "verbosity"),
    ("p", "probSpecsDir"),
    ("o", "offline"),
    ("h", "help"),
    ("_", "version"), # No short option for `--version`
  ]

  optsNoVal = {optCheck, optOffline, optHelp, optVersion}

func short(opt: Opt): string =
  result = optKeys[opt].short

func long(opt: Opt): string =
  result = optKeys[opt].long

func list(opt: Opt): string =
  if opt.short == "_":
    &"    --{opt.long}"
  else:
    &"-{opt.short}, --{opt.long}"

proc showHelp =
  let applicationName = extractFilename(getAppFilename())

  echo &"""Usage: {applicationName} [options]

Options:
  {list(optExercise)} <slug>        Only sync this exercise
  {list(optCheck)}                  Terminates with a non-zero exit code if one or more tests are missing. Doesn't update the tests
  {list(optMode)} <mode>            What to do with missing test cases. Allowed values: c[hoose], i[nclude], e[xclude]
  {list(optVerbosity)} <verbosity>  The verbosity of output. Allowed values: q[uiet], n[ormal], d[etailed]
  {list(optProbSpecsDir)} <dir>     Use this `problem-specifications` directory, rather than cloning temporarily
  {list(optOffline)}                Do not check that the directory specified by `{list(optProbSpecsDir)}` is up-to-date
  {list(optHelp)}                   Show this help message and exit
  {list(optVersion)}                Show this tool's version information and exit"""

  quit(0)

proc showVersion =
  echo &"Canonical Data Syncer v{NimblePkgVersion}"
  quit(0)

proc showError*(s: string) =
  stdout.styledWrite(fgRed, "Error: ")
  stdout.write(s)
  stdout.write("\n\n")
  showHelp()

proc prefix(kind: CmdLineKind): string =
  case kind
  of cmdShortOption: "-"
  of cmdLongOption: "--"
  of cmdArgument, cmdEnd, cmdError: ""

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

func normalizeOption(s: string): string =
  ## Returns the string `s`, but converted to lowercase and without '_' or '-'.
  result = newString(s.len)
  var i = 0
  for c in s:
    if c in {'A'..'Z'}:
      result[i] = toLowerAscii(c)
      inc i
    elif c notin {'_', '-'}:
      result[i] = c
      inc i
  if i != s.len:
    setLen(result, i)

proc processCmdLine*: Conf =
  result = initConf()

  var shortNoVal: set[char]
  var longNoVal = newSeqOfCap[string](optsNoVal.len)
  for opt in optsNoVal:
    shortNoVal.incl(opt.short[0])
    longNoVal.add(opt.long)

  for kind, key, val in getopt(shortNoVal = shortNoVal, longNoVal = longNoVal):
    case kind
    of cmdLongOption, cmdShortOption:
      case key.normalizeOption()
      of optExercise.short, optExercise.long:
        showErrorForMissingVal(kind, key, val)
        result.exercise = some(val)
      of optCheck.short, optCheck.long:
        result.action = actCheck
      of optMode.short, optMode.long:
        showErrorForMissingVal(kind, key, val)
        result.mode = parseMode(kind, key, val)
      of optVerbosity.short, optVerbosity.long:
        showErrorForMissingVal(kind, key, val)
        result.verbosity = parseVerbosity(kind, key, val)
      of optProbSpecsDir.short, optProbSpecsDir.long.toLowerAscii():
        showErrorForMissingVal(kind, key, val)
        result.probSpecsDir = some(val)
      of optOffline.short, optOffline.long:
        result.offline = true
      of optHelp.short, optHelp.long:
        showHelp()
      of optVersion.short, optVersion.long:
        showVersion()
      else:
        showError(&"invalid option: '{kind.prefix}{key}'")
    of cmdArgument:
      case key.toLowerAscii
      of optHelp.long:
        showHelp()
      else:
        showError(&"invalid argument: '{key}'")
    # cmdError can only occur if we pass `requireSep = true` to `getopt`.
    of cmdEnd, cmdError:
      discard

  if result.offline and result.probSpecsDir.isNone():
    showError(&"'{list(optOffline)}' was given without passing '{list(optProbSpecsDir)}'")
