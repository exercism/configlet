import options, os, parseopt, sequtils, strformat, strutils

type
  Command* = enum
    check, update

  Verbosity* = enum
    quiet, normal, detailed

  Arguments* = object
    command*: Command
    verbosity*: Verbosity
    exercise*: Option[string]

const NimblePkgVersion {.strdefine}: string = "unknown"

proc showHelp() =
  let commandOptions = toSeq(Command).join("|")
  let verbosityOptions = toSeq(Verbosity).mapIt(&"[{($it)[0]}]{($it)[1..^1]}").join("|")
  let applicationName = extractFileName(getAppFilename())

  echo &"Usage: {applicationName} [options] {{{commandOptions}}}"
  echo ""
  echo "Options:"
  echo "  -e, --exercise <slug>       Check/update only this exercise"
  echo &"  -l, --loglevel <verbosity>  Set the verbosity level: {verbosityOptions}"
  echo "  -h, --help                  Show CLI usage" 
  echo "  -v, --version               Display version information"

proc showVersion() = 
  echo &"Canonical Data Syncer v{NimblePkgVersion}"

var filename: string
var p = initOptParser("--left --debug:3 -l -r:2")

for kind, key, val in p.getopt():
  case kind
  of cmdArgument:
    filename = key
  of cmdLongOption, cmdShortOption:
    case key
    of "help", "h": showHelp()
    of "version", "v": showVersion()
  of cmdEnd: assert(false) # cannot happen
if filename == "":
  # no filename has been given, so we show the help
  showHelp()


proc noParameters: bool =
  paramCount() == 0

proc commandParameter: string =
  paramStr(1)

proc exerciseParameter: string =
  paramStr(2)

proc parseCommand: Command =
  try:
    result = parseEnum[Command](commandParameter())
  except ValueError:
    quit(QuitFailure)

proc parseExercise: Option[string] =
  if paramCount() >= 2:
    result = some(exerciseParameter())

proc parseArguments*: Arguments =
  if noParameters():
      showHelp()
      quit(QuitFailure)

  # TODO: parse verbosity
  result.command = parseCommand()
  result.exercise = parseExercise()
