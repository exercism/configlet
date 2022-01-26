import std/[os, parseutils, strformat, strutils, terminal]
import pkg/cligen/parseopt3

type
  ActionKind* = enum
    actNil = "nil"
    actFmt = "fmt"
    actGenerate = "generate"
    actInfo = "info"
    actLint = "lint"
    actSync = "sync"
    actUuid = "uuid"

  SyncKind* = enum
    skDocs = "docs"
    skFilepaths = "filepaths"
    skMetadata = "metadata"
    skTests = "tests"

  TestsMode* = enum
    tmChoose = "choose"
    tmInclude = "include"
    tmExclude = "exclude"

  Action* = object
    case kind*: ActionKind
    of actNil, actGenerate, actInfo, actLint:
      discard
    of actFmt:
      # We can't name these fields `exercise`, `update`, and `yes` because we
      # use those names in `actSync`, and Nim doesn't yet support duplicate
      # field names in object variants.
      exerciseFmt*: string
      updateFmt*: bool
      yesFmt*: bool
    of actSync:
      exercise*: string
      probSpecsDir*: string
      offline*: bool
      update*: bool
      yes*: bool
      scope*: set[SyncKind]
      tests*: TestsMode
    of actUuid:
      num*: int

  Verbosity* = enum
    verQuiet = "quiet"
    verNormal = "normal"
    verDetailed = "detailed"

  Conf* = object
    action*: Action
    trackDir*: string
    verbosity*: Verbosity

  Opt* = enum
    # Global options
    optHelp = "help"
    optVersion = "version"
    optTrackDir = "trackDir"
    optVerbosity = "verbosity"

    # Options for both `fmt` and `sync`
    optFmtSyncExercise = "exercise"
    optFmtSyncUpdate = "update"
    optFmtSyncYes = "yes"

    # Options for `sync`
    optSyncProbSpecsDir = "probSpecsDir"
    optSyncOffline = "offline"
    # Scope to sync
    optSyncDocs = "docs"
    optSyncFilepaths = "filepaths"
    optSyncMetadata = "metadata"
    optSyncTests = "tests"

    # Options for `uuid`
    optUuidNum = "num"

func genShortKeys: array[Opt, char] =
  ## Returns a lookup that gives the valid short option key for an `Opt`.
  for opt in Opt:
    if opt in {optVersion, optSyncDocs, optSyncFilepaths, optSyncMetadata,
               optSyncTests}:
      result[opt] = '_' # No short option for these options.
    else:
      result[opt] = ($opt)[0]

const
  repoRootDir = currentSourcePath().parentDir().parentDir()
  configletVersion = staticRead(repoRootDir / "configlet.version").strip()
  short = genShortKeys()
  optsNoVal = {optHelp, optVersion, optFmtSyncUpdate, optFmtSyncYes,
               optSyncOffline, optSyncDocs, optSyncFilepaths, optSyncMetadata}

func generateNoVals: tuple[shortNoVal: set[char], longNoVal: seq[string]] =
  ## Returns the short and long keys for the options in `optsNoVal`.
  result.shortNoVal = {}
  result.longNoVal = newSeq[string](optsNoVal.len)
  var i = 0
  for opt in optsNoVal:
    result.shortNoVal.incl(short[opt])
    result.longNoVal[i] = $opt
    inc i

const
  (shortNoVal, longNoVal) = generateNoVals()

func camelToKebab(s: string): string =
  ## Converts the string `s` to lowercase, adding a `-` before each previously
  ## uppercase letter.
  result = newStringOfCap(s.len + 2)
  for c in s:
    if c in {'A'..'Z'}:
      result.add '-'
      result.add toLowerAscii(c)
    else:
      result.add c

func list*(opt: Opt): string =
  if short[opt] == '_':
    &"    --{camelToKebab($opt)}"
  else:
    &"-{short[opt]}, --{camelToKebab($opt)}"

func genHelpText: string =
  ## Generates a string that describes every configlet command and option, to be
  ## shown in the `configlet --help` message.

  func allowedValues(T: typedesc[enum]): string =
    ## Returns a string that describes the allowed values for an enum `T`.
    result = "Allowed values: "
    for val in T:
      result.add &"{($val)[0]}"
      result.add &"[{($val)[1 .. ^1]}], "
    setLen(result, result.len - 2)

  func genSyntaxStrings: tuple[syntax: array[Opt, string], maxLen: int] =
    ## Returns:
    ## - A lookup that returns the start of the help text for each option.
    ## - The length of the longest string in the above, which is useful to
    ##   set the column width.
    for opt in Opt:
      let paramName =
        case opt
        of optTrackDir: "dir"
        of optVerbosity: "verbosity"
        of optFmtSyncExercise: "slug"
        of optSyncTests: "mode"
        of optSyncProbSpecsDir: "dir"
        of optUuidNum: "int"
        else: ""

      let paramText =
        if paramName.len > 0:
          if opt == optSyncTests:
            &" [{paramName}]" # Mode argument is optional. Default is `choose`.
          else:
            &" <{paramName}>"
        else:
          ""
      let optText = &"  {opt.list}{paramText}  "
      result.syntax[opt] = optText
      result.maxLen = max(result.maxLen, optText.len)

  func getLongestActionLen: int =
    result = -1
    for actionKind in ActionKind:
      result = max(result, actionKind.`$`.len)

  const longestActionLen = getLongestActionLen()
  const paddingAction = repeat(' ', longestActionLen + 4)

  const actionDescriptions: array[ActionKind, string] = [
    actNil: "",
    actFmt: "Format the exercise 'meta/config.json' files",
    actGenerate: "Generate Concept Exercise 'introduction.md' files from 'introduction.md.tpl' files",
    actInfo: "Print some information about the track",
    actLint: "Check the track configuration for correctness",
    actSync: "Check or update Practice Exercise docs, metadata, and tests from 'problem-specifications'.\n" &
             &"{paddingAction}Check or populate missing 'files' values for Concept/Practice Exercises from the track 'config.json'.",
    actUuid: "Output new (version 4) UUIDs, suitable for the value of a 'uuid' key",
  ]

  const (syntax, maxLen) = genSyntaxStrings()
  const paddingOpt = repeat(' ', maxLen)

  # For some options that are common between commands, we want different
  # descriptions in the help message. But we currently use `parseEnum` to parse
  # a user-provided option, and so `Opt` can't have e.g. separate `optSyncYes`
  # and `optFmtYes` values with the same string value of "yes".
  # We define most of the option descriptions below. For the options that are
  # common to both `sync` and `fmt`, we set the `sync` descriptions here and
  # set the `fmt` ones later.
  const descriptions: array[Opt, string] = [
    optHelp: "Show this help message and exit",
    optVersion: "Show this tool's version information and exit",
    optTrackDir: "Specify a track directory to use instead of the current directory",
    optVerbosity: &"The verbosity of output.\n" &
                  &"{paddingOpt}{allowedValues(Verbosity)} (default: normal)",
    optFmtSyncExercise: "Only operate on this exercise",
    optFmtSyncUpdate: "Prompt to update the seen data that are unsynced",
    optFmtSyncYes: &"Auto-confirm prompts from --{$optFmtSyncUpdate} for updating docs, filepaths, and metadata",
    optSyncProbSpecsDir: "Use this 'problem-specifications' directory, " &
                         "rather than cloning temporarily",
    optSyncOffline: "Do not check that the directory specified by " &
                    &"--{camelToKebab($optSyncProbSpecsDir)} is up to date",
    optSyncDocs: "Sync Practice Exercise '.docs/introduction.md' and '.docs/instructions.md' files",
    optSyncFilepaths: "Populate empty 'files' values in Concept/Practice exercise '.meta/config.json' files",
    optSyncMetadata: "Sync Practice Exercise '.meta/config.json' metadata values",
    optSyncTests: &"Sync Practice Exercise '.meta/tests.toml' files.\n" &
                  &"{paddingOpt}The mode value specifies how missing tests are handled when using --{$optFmtSyncUpdate}.\n" &
                  &"{paddingOpt}{allowedValues(TestsMode)} (default: choose)",
    optUuidNum: "Number of UUIDs to output",
  ]

  result = "Commands:\n"

  # Add descriptions for commands.
  for action in ActionKind:
    if action != actNil:
      result.add &"  {alignLeft($action, longestActionLen)}  {actionDescriptions[action]}\n"

  # Add descriptions for command options.
  var optSeen: set[Opt] = {}
  for actionKind in ActionKind:
    if actionKind notin {actNil, actLint, actGenerate, actInfo}:
      result.add &"\nOptions for {actionKind}:\n"
      let action = Action(kind: actionKind)
      for key, val in fieldPairs(action):
        if key == "scope":
          for syncKind in {skDocs, skFilepaths, skMetadata}:
            let opt = parseEnum[Opt]($syncKind)
            result.add alignLeft(syntax[opt], maxLen) & descriptions[opt] & "\n"
            optSeen.incl opt
        elif key != "kind":
          let opt =
            case key
            of "exerciseFmt":
              optFmtSyncExercise
            of "updateFmt":
              optFmtSyncUpdate
            of "yesFmt":
              optFmtSyncYes
            else:
              parseEnum[Opt](key)
          # Set the description for `fmt` options.
          let desc =
            if actionKind == actFmt and opt == optFmtSyncUpdate:
              "Prompt to write formatted files"
            elif actionKind == actFmt and opt == optFmtSyncYes:
              &"Auto-confirm the prompt from --{$optFmtSyncUpdate}"
            else:
              descriptions[opt]
          result.add alignLeft(syntax[opt], maxLen) & desc & "\n"
          optSeen.incl opt

  # Add descriptions for global options.
  result.add &"\nGlobal options:\n"
  for opt in Opt:
    if opt notin optSeen:
      result.add alignLeft(syntax[opt], maxLen) & descriptions[opt] & "\n"
  setLen(result, result.len - 1)

proc showHelp(exitCode: range[0..255] = 0) =
  const helpText = genHelpText()
  let appName = extractFilename(getAppFilename())
  let usage = "Usage:\n" &
              &"  {appName} [global-options] <command> [command-options]\n"
  let f = if exitCode == 0: stdout else: stderr
  f.writeLine usage
  f.writeLine helpText
  if f == stdout:
    f.flushFile()
  quit(exitCode)

proc showVersion =
  echo &"{configletVersion}"
  quit(0)

proc shouldUseColor(f: File): bool =
  ## Returns true if we should write to `f` with color.
  existsEnv("CI") or
    (isatty(f) and not existsEnv("NO_COLOR") and getEnv("TERM") != "dumb")

let
  colorStdout* = shouldUseColor(stdout)
  colorStderr* = shouldUseColor(stderr)

proc showError*(s: string) =
  const errorPrefix = "Error: "
  if colorStderr:
    stderr.styledWrite(fgRed, errorPrefix)
  else:
    stderr.write(errorPrefix)
  stderr.write(s)
  stderr.write("\n\n")
  showHelp(exitCode = 1)

func formatOpt(kind: CmdLineKind, key: string, val = ""): string =
  ## Returns a string that describes an option, given its `kind`, `key` and
  ## optionally `val`. This is useful for displaying in error messages.
  runnableExamples:
    import pkg/cligen/parseopt3
    assert formatOpt(cmdShortOption, "h") == "'-h'"
    assert formatOpt(cmdLongOption, "help") == "'--help'"
    assert formatOpt(cmdShortOption, "v", "quiet") == "'-v': 'quiet'"
  let prefix =
    case kind
    of cmdShortOption: "-"
    of cmdLongOption: "--"
    of cmdArgument, cmdEnd, cmdError: ""
  result =
    if val.len > 0:
      &"'{prefix}{key}': '{val}'"
    else:
      &"'{prefix}{key}'"

func initAction*(actionKind: ActionKind, probSpecsDir = "",
                 scope: set[SyncKind] = {}): Action =
  case actionKind
  of actNil, actFmt, actGenerate, actInfo, actLint:
    Action(kind: actionKind)
  of actSync:
    Action(kind: actionKind, probSpecsDir: probSpecsDir, scope: scope)
  of actUuid:
    Action(kind: actionKind, num: 1)

func initConf*(action = initAction(actNil), trackDir = getCurrentDir(),
               verbosity = verNormal): Conf =
  result = Conf(
    action: action,
    trackDir: trackDir,
    verbosity: verbosity,
  )

proc parseActionKind(key: string): ActionKind =
  ## Parses `key` as an `ActionKind`, using a case-insensitive comparison.
  ##
  ## Raises an error if `key` cannot be parsed as a `ActionKind`.
  var keyNormalized = toLowerAscii(key)
  if keyNormalized == "help": showHelp()
  try:
    result = parseEnum[ActionKind](keyNormalized)
  except ValueError:
    if keyNormalized == "format":
      showError(&"invalid command: '{key}'\nDid you mean 'fmt'?")
    else:
      showError(&"invalid command: '{key}'")

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
    if val.len == 0 and result notin optsNoVal and result != optSyncTests:
      showError(&"{formatOpt(kind, key)} was given without a value")
  except ValueError:
    showError(&"invalid option: {formatOpt(kind, key)}")

proc parseVal[T: enum](kind: CmdLineKind, key: string, val: string): T =
  ## Parses `val` as a value of the enum `T`, using a case-insensitive
  ## comparsion.
  ##
  ## Exits with an error if `key` cannot be parsed as a value of `T`.
  when T is TestsMode:
    if val.len == 0:
      return tmChoose
  var valNormalized = toLowerAscii(val)
  # Convert a valid single-letter abbreviation to the string value of the enum.
  if valNormalized.len == 1:
    for e in T:
      if valNormalized[0] == ($e)[0]:
        valNormalized = $e
        break
  try:
    result = parseEnum[T](valNormalized)
  except ValueError:
    showError(&"invalid value for {formatOpt(kind, key, val)}")

proc handleArgument(conf: var Conf; kind: CmdLineKind; key: string) =
  if conf.action.kind == actNil:
    let actionKind = parseActionKind(key)
    let action = initAction(actionKind)
    conf = initConf(action, conf.trackDir, conf.verbosity)
  else:
    showError(&"invalid argument for command '{conf.action.kind}': '{key}'")

template setGlobalOpt(key, val: untyped) =
  conf.key = val
  isGlobalOpt = true

template setActionOpt(key, val: untyped) =
  conf.action.key = val
  isActionOpt = true

proc handleOption(conf: var Conf; kind: CmdLineKind; key, val: string) =
  let opt = parseOption(kind, key, val)

  var
    isGlobalOpt = false
    isActionOpt = false

  # Process global options
  case opt
  of optHelp:
    showHelp()
  of optVersion:
    showVersion()
  of optTrackDir:
    setGlobalOpt(trackDir, val)
  of optVerbosity:
    setGlobalOpt(verbosity, parseVal[Verbosity](kind, key, val))
  else:
    discard

  # Process action-specific options
  if not isGlobalOpt:
    case conf.action.kind
    of actNil, actGenerate, actInfo, actLint:
      discard
    of actFmt:
      case opt
      of optFmtSyncExercise:
        setActionOpt(exerciseFmt, val)
      of optFmtSyncUpdate:
        setActionOpt(updateFmt, true)
      of optFmtSyncYes:
        setActionOpt(yesFmt, true)
      else:
        discard
    of actSync:
      case opt
      of optFmtSyncExercise:
        setActionOpt(exercise, val)
      of optFmtSyncUpdate:
        setActionOpt(update, true)
      of optFmtSyncYes:
        setActionOpt(yes, true)
      of optSyncTests:
        setActionOpt(tests, parseVal[TestsMode](kind, key, val))
        conf.action.scope.incl skTests
      of optSyncProbSpecsDir:
        setActionOpt(probSpecsDir, val)
      of optSyncOffline:
        setActionOpt(offline, true)
      of optSyncDocs, optSyncMetadata, optSyncFilepaths:
        conf.action.scope.incl parseEnum[SyncKind]($opt)
        isActionOpt = true
      else:
        discard
    of actUuid:
      case opt
      of optUuidNum:
        var num = -1
        discard parseSaturatedNatural(val, num)
        if num < 1:
          showError(&"value for {formatOpt(kind, key)} is not a positive " &
                    &"integer: {val}")
        setActionOpt(num, num)
      else:
        discard

  if not isGlobalOpt and not isActionOpt:
    case conf.action.kind
    of actNil:
      showError(&"invalid global option: {formatOpt(kind, key)}")
    else:
      showError(&"invalid option for '{conf.action.kind}': " &
                &"{formatOpt(kind, key)}")

proc processCmdLine*: Conf =
  result = initConf()

  for kind, key, val in getopt(shortNoVal = shortNoVal, longNoVal = longNoVal):
    case kind
    of cmdArgument:
      handleArgument(result, kind, key)
    of cmdLongOption, cmdShortOption:
      handleOption(result, kind, key, val)
    # cmdError can only occur if we pass `requireSep = true` to `getopt`.
    of cmdEnd, cmdError:
      discard

  case result.action.kind
  of actNil:
    showHelp()
  of actFmt, actGenerate, actInfo, actLint, actUuid:
    discard
  of actSync:
    # If the user does not specify a syncing scope, operate on all data kinds.
    if result.action.scope.len == 0:
      result.action.scope = {SyncKind.low .. SyncKind.high}
