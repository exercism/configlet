import std/[os, parseutils, strformat, strutils, terminal]
import pkg/cligen/parseopt3

type
  Verbosity* = enum
    verQuiet = "quiet"
    verNormal = "normal"
    verDetailed = "detailed"

  Mode* = enum
    modeChoose = "choose"
    modeInclude = "include"
    modeExclude = "exclude"

  ActionKind* = enum
    actNil = "nil"
    actLint = "lint"
    actSync = "sync"
    actUuid = "uuid"
    actGenerate = "generate"
    actInfo = "info"

  SyncKind* = enum
    skDocs = "docs"
    skFilepaths = "filepaths"
    skMetadata = "metadata"
    skTests = "tests"

  Action* = object
    case kind*: ActionKind
    of actNil:
      discard
    of actLint:
      discard
    of actSync:
      exercise*: string
      mode*: Mode
      probSpecsDir*: string
      offline*: bool
      update*: bool
      yes*: bool
      scope*: set[SyncKind]
    of actUuid:
      num*: int
    of actGenerate:
      discard
    of actInfo:
      discard

  Conf* = object
    action*: Action
    trackDir*: string
    verbosity*: Verbosity

  Opt = enum
    # Global options
    optHelp = "help"
    optVersion = "version"
    optTrackDir = "trackDir"
    optVerbosity = "verbosity"

    # Options for `sync`
    optSyncExercise = "exercise"
    optSyncMode = "mode"
    optSyncProbSpecsDir = "probSpecsDir"
    optSyncOffline = "offline"
    optSyncUpdate = "update"
    optSyncYes = "yes"
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
  optsNoVal = {optHelp, optVersion, optSyncOffline, optSyncUpdate, optSyncYes,
               optSyncDocs, optSyncFilepaths, optSyncMetadata, optSyncTests}

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
      result &= '-'
      result &= toLowerAscii(c)
    else:
      result &= c

func list(opt: Opt): string =
  if short[opt] == '_':
    &"    --{camelToKebab($opt)}"
  else:
    &"-{short[opt]}, --{camelToKebab($opt)}"

func genHelpText: string =
  ## Returns a string that lists all the CLI options.

  func allowedValues(T: typedesc[enum]): string =
    ## Returns a string that describes the allowed values for an enum `T`.
    result = "Allowed values: "
    for val in T:
      result &= &"{($val)[0]}"
      result &= &"[{($val)[1 .. ^1]}], "
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
        of optSyncExercise: "slug"
        of optSyncMode: "mode"
        of optSyncProbSpecsDir: "dir"
        of optUuidNum: "int"
        else: ""

      let paramText = if paramName.len > 0: &" <{paramName}>" else: ""
      let optText = &"  {opt.list}{paramText}  "
      result.syntax[opt] = optText
      result.maxLen = max(result.maxLen, optText.len)

  const (syntax, maxLen) = genSyntaxStrings()

  const descriptions: array[Opt, string] = [
    optHelp: "Show this help message and exit",
    optVersion: "Show this tool's version information and exit",
    optTrackDir: "Specify a track directory to use instead of the current directory",
    optVerbosity: &"The verbosity of output. {allowedValues(Verbosity)}",
    optSyncExercise: "Only operate on this exercise",
    optSyncMode: &"What to do with missing test cases. {allowedValues(Mode)}",
    optSyncProbSpecsDir: "Use this `problem-specifications` directory, " &
                         "rather than cloning temporarily",
    optSyncOffline: "Do not check that the directory specified by " &
                    &"`{list(optSyncProbSpecsDir)}` is up-to-date",
    optSyncUpdate: "Update unsynced docs, filepaths, metadata, and tests",
    optSyncYes: "Auto-confirm every prompt for updating docs, filepaths, and metadata",
    optSyncDocs: "Sync `.docs/introduction.md` and `.docs/instructions.md`",
    optSyncFilepaths: "Sync filepaths",
    optSyncMetadata: "Sync metadata",
    optSyncTests: "Sync tests",
    optUuidNum: "Number of UUIDs to generate",
  ]

  result = "Commands:\n  "

  for action in ActionKind:
    if action != actNil:
      result &= $action & ", "
  setLen(result, result.len - 2)
  result &= "\n"

  var optSeen: set[Opt] = {}
  for actionKind in ActionKind:
    if actionKind notin {actNil, actLint, actGenerate, actInfo}:
      result &= &"\nOptions for {actionKind}:\n"
      let action = Action(kind: actionKind)
      for key, val in fieldPairs(action):
        if key == "scope":
          for syncKind in SyncKind:
            let opt = parseEnum[Opt]($syncKind)
            result &= alignLeft(syntax[opt], maxLen) & descriptions[opt] & "\n"
            optSeen.incl opt
        elif key != "kind":
          let opt = parseEnum[Opt](key)
          result &= alignLeft(syntax[opt], maxLen) & descriptions[opt] & "\n"
          optSeen.incl opt

  result &= &"\nGlobal options:\n"
  for opt in Opt:
    if opt notin optSeen:
      result &= alignLeft(syntax[opt], maxLen) & descriptions[opt] & "\n"
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
  of actNil:
    Action(kind: actionKind)
  of actLint:
    Action(kind: actionKind)
  of actSync:
    Action(kind: actionKind, probSpecsDir: probSpecsDir, scope: scope)
  of actUuid:
    Action(kind: actionKind, num: 1)
  of actGenerate:
    Action(kind: actionKind)
  of actInfo:
    Action(kind: actionKind)

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
    if val.len == 0 and result notin optsNoVal:
      showError(&"{formatOpt(kind, key)} was given without a value")
  except ValueError:
    showError(&"invalid option: {formatOpt(kind, key)}")

proc parseVal[T: enum](kind: CmdLineKind, key: string, val: string): T =
  ## Parses `val` as a value of the enum `T`, using a case-insensitive
  ## comparsion.
  ##
  ## Exits with an error if `key` cannot be parsed as a value of `T`.
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
    of actNil:
      discard
    of actLint:
      discard
    of actSync:
      case opt
      of optSyncExercise:
        setActionOpt(exercise, val)
      of optSyncMode:
        setActionOpt(mode, parseVal[Mode](kind, key, val))
      of optSyncProbSpecsDir:
        setActionOpt(probSpecsDir, val)
      of optSyncOffline:
        setActionOpt(offline, true)
      of optSyncUpdate:
        setActionOpt(update, true)
      of optSyncYes:
        setActionOpt(yes, true)
      of optSyncDocs, optSyncMetadata, optSyncFilepaths, optSyncTests:
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
    of actGenerate:
      discard
    of actInfo:
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
  of actLint:
    discard
  of actSync:
    if result.action.offline and result.action.probSpecsDir.len == 0:
      showError(&"'{list(optSyncOffline)}' was given without passing " &
                &"'{list(optSyncProbSpecsDir)}'")
    if result.action.scope.len == 0:
      result.action.scope = {SyncKind.low .. SyncKind.high}
    if result.action.update and result.action.yes and skTests in result.action.scope:
      let msg = fmt"""
        '{list(optSyncYes)}' cannot be used when updating tests
        You can either:
        - remove '{list(optSyncYes)}'
        - or narrow the syncing scope via some combination of --docs, --filepaths, and --metadata
        If no syncing scope option is provided, configlet uses the full syncing scope""".unindent()
      showError(msg)
  of actUuid:
    discard
  of actGenerate:
    discard
  of actInfo:
    discard
