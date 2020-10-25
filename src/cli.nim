import std/[options, os, strformat, strutils, terminal]
import pkg/[cligen/parseopt3]

type
  Action* = enum
    actSync, actCheck

  Mode* = enum
    modeChoose, modeInclude, modeExclude

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
    optExercise = "exercise"
    optCheck = "check"
    optMode = "mode"
    optVerbosity = "verbosity"
    optProbSpecsDir = "probSpecsDir"
    optOffline = "offline"
    optHelp = "help"
    optVersion = "version"

func genShortKeys: array[Opt, char] =
  ## Returns a lookup that gives the valid short option key for an `Opt`.
  for opt in Opt:
    if opt == optVersion:
      result[opt] = '_' # No short option for `--version`
    else:
      result[opt] = ($opt)[0]

const
  NimblePkgVersion {.strdefine.}: string = "unknown"

  short = genShortKeys()

  optsNoVal = {optCheck, optOffline, optHelp, optVersion}

func list(opt: Opt): string =
  if short[opt] == '_':
    &"    --{$opt}"
  else:
    &"-{short[opt]}, --{$opt}"

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

proc parseMode(kind: CmdLineKind, key: string, val: string): Mode =
  case val.toLowerAscii
  of "c", "choose":
    result = modeChoose
  of "i", "include":
    result = modeInclude
  of "e", "exclude":
    result = modeExclude
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

proc parseOption(kind: CmdLineKind, key: string, val: string): Opt =
  ## Parses `key` as an `Opt`, using a style-insensitive comparison.
  ##
  ## Raises an error:
  ## - if `key` cannot be parsed as an `Opt`.
  ## - if the parsed `Opt` requires a value, but `val` is of zero-length.
  var keyNormalized = normalizeOption(key)
  # Parse a valid single-letter abbreviation.
  if keyNormalized.len == 1:
    for opt in Opt:
      if keyNormalized[0] == short[opt]:
        keyNormalized = $opt
        break
  try:
    result = parseEnum[Opt](keyNormalized) # `parseEnum` does not normalize for `-`.
    if val.len == 0 and result notin optsNoVal:
      showError(&"'{prefix(kind)}{key}' was given without a value")
  except ValueError:
    showError(&"invalid option: '{prefix(kind)}{key}'")

proc processCmdLine*: Conf =
  result = initConf()

  var shortNoVal: set[char]
  var longNoVal = newSeqOfCap[string](optsNoVal.len)
  for opt in optsNoVal:
    shortNoVal.incl(short[opt])
    longNoVal.add($opt)

  for kind, key, val in getopt(shortNoVal = shortNoVal, longNoVal = longNoVal):
    case kind
    of cmdLongOption, cmdShortOption:
      case parseOption(kind, key, val)
      of optExercise:
        result.exercise = some(val)
      of optCheck:
        result.action = actCheck
      of optMode:
        result.mode = parseMode(kind, key, val)
      of optVerbosity:
        result.verbosity = parseVerbosity(kind, key, val)
      of optProbSpecsDir:
        result.probSpecsDir = some(val)
      of optOffline:
        result.offline = true
      of optHelp:
        showHelp()
      of optVersion:
        showVersion()
    of cmdArgument:
      case key.toLowerAscii
      of $optHelp:
        showHelp()
      else:
        showError(&"invalid argument: '{key}'")
    # cmdError can only occur if we pass `requireSep = true` to `getopt`.
    of cmdEnd, cmdError:
      discard

  if result.offline and result.probSpecsDir.isNone():
    showError(&"'{list(optOffline)}' was given without passing '{list(optProbSpecsDir)}'")
