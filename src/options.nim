import os, sequtils, strformat, strutils

type
  Command* = enum
    check, update

  Options* = object
    command*: Command

let commands = toSeq(Command.items).join("|")
let describeUsage = &"Usage: {extractFileName(getAppFilename())} [{commands}]"

proc noParameters: bool =
  paramCount() == 0

proc commandParameter: string =
  paramStr(1)

proc parseCommand: Command =
  parseEnum[Command](commandParameter())

proc parseOptions*: Options =
  if noParameters():
      quit(describeUsage)

  try:
    result.command = parseCommand()
  except ValueError:
    echo &"Invalid command specified: {commandParameter()}"
    quit(describeUsage)
