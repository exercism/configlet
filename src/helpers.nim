import std/[algorithm, os, strformat, terminal]
import "."/cli

template withDir*(dir: string; body: untyped): untyped =
  ## Changes the current directory to `dir` temporarily.
  let startDir = getCurrentDir()
  try:
    setCurrentDir(dir)
    body
  finally:
    setCurrentDir(startDir)

type
  Path* {.requiresInit.} = distinct string

# Borrow these two operators so that we can use `sort`.
proc `==`(x, y: Path): bool {.borrow.}
proc `<`(x, y: Path): bool {.borrow.}

proc getSortedSubdirs*(dir: Path): seq[Path] =
  ## Returns a seq of the subdirectories of `dir`, in alphabetical order.
  result = newSeqOfCap[Path](100)
  for kind, path in walkDir(dir.string):
    if kind == pcDir:
      result.add Path(path)
  sort result

proc setFalseAndPrint*(b: var bool; description: string; path: Path) =
  ## Sets `b` to `false` and writes a message to stdout containing `description`
  ## and `path`.
  b = false
  let descriptionPrefix = description & ":"
  if colorStdout:
    stdout.styledWriteLine(fgRed, descriptionPrefix)
  else:
    stdout.writeLine(descriptionPrefix)
  stdout.writeLine(path.string)
  stdout.write "\n"

var printedWarning* = false

proc warn*(msg: string; extra = ""; doubleFinalNewline = true) =
  ## Writes `msg` to stdout, in color when appropriate. If `extra` is provided,
  ## it is written on its own line, without color.
  if colorStdout:
    stdout.styledWriteLine(fgYellow, msg)
  else:
    stdout.write "Warning: "
    stdout.writeLine(msg)
  if extra.len > 0:
    stdout.writeLine(extra)
  if doubleFinalNewline:
    stdout.write "\n"
  printedWarning = true

proc warn*(description: string; path: Path) =
  ## Writes a message to stdout containing `description` and `path`.
  let msg = &"{description}:"
  warn(msg, path.string)

proc `$`*(path: Path): string {.borrow.}
proc `/`*(head: Path; tail: string): Path {.borrow.}

proc dirExists*(path: Path): bool {.borrow.}
proc fileExists*(path: Path): bool {.borrow.}
proc readFile*(path: Path): string {.borrow.}
proc writeFile*(path: Path; content: string) {.borrow.}
