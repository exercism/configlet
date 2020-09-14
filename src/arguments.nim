import options, os, sequtils, strformat, strutils

type
  Command* = enum
    check, update

  Verbosity* = enum
    quiet, normal, detailed

  Arguments* = object
    command*: Command
    verbosity*: Verbosity
    exercise*: Option[string]

let commands = toSeq(Command.items).join("|")
let describeUsage = &"Usage: {extractFileName(getAppFilename())} [{commands}] [exercise]"

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
    echo &"Invalid command specified: {commandParameter()}"
    quit(describeUsage)

proc parseExercise: Option[string] =
  if paramCount() >= 2:
    result = some(exerciseParameter())

proc parseArguments*: Arguments =
  if noParameters():
      quit(describeUsage)

  # TODO: parse verbosity
  result.command = parseCommand()
  result.exercise = parseExercise()
