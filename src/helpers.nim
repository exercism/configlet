import std/[algorithm, os, parseutils, strformat, strscans, strutils, terminal]
import pkg/jsony
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
proc `==`*(x, y: Path): bool {.borrow.}
proc `<`*(x, y: Path): bool {.borrow.}

proc getSortedPaths(dir: Path; pc: PathComponent; relative: bool;
                    pattern: static string): seq[Path] =
  result = @[]
  for kind, path in walkDir(dir.string, relative = relative):
    if kind == pc and (pattern.len == 0 or path.scanf(pattern)):
      result.add Path(path)
  sort result

proc getSortedSubdirs*(dir: Path; relative = false;
                       pattern: static string = ""): seq[Path] =
  ## Returns the names of directories in `dir`, in alphabetical order, limited
  ## to those that match the scanf `pattern` if it has non-zero length. The
  ## `pattern` must not contain a matcher that binds (e.g. `$i`, `$*`, `$+`).
  ##
  ## Can be used at compile time, unlike `os.walkDirs` and `os.walkPattern`.
  getSortedPaths(dir, pcDir, relative, pattern)

proc getSortedFiles*(dir: Path; relative = false;
                     pattern: static string = ""): seq[Path] =
  ## Returns the names of files in `dir`, in alphabetical order, limited to
  ## those that match the scanf `pattern` if it has non-zero length. The
  ## `pattern` must not contain a matcher that binds (e.g. `$i`, `$*`, `$+`).
  ##
  ## Can be used at compile time, unlike `os.walkFiles` and `os.walkPattern`.
  getSortedPaths(dir, pcFile, relative, pattern)

func w*(s: string; start: int): int =
  ## A matcher for `scanf`. Similar to `$w`, but only skips (does not bind).
  s.skipWhile(IdentChars, start)

proc setFalseAndPrint*(b: var bool; description: string; path: Path, annotation = "") =
  ## Sets `b` to `false` and writes a message to stdout containing `description`
  ## and `path`.
  b = false
  let descriptionPrefix = description & ":"
  if colorStdout:
    stdout.styledWriteLine(fgRed, descriptionPrefix)
  else:
    stdout.writeLine(descriptionPrefix)
  stdout.writeLine(path.string)
  if annotation.len > 0:
    if colorStdout:
      stdout.styledWriteLine(fgYellow, annotation)
    else:
      stdout.writeLine(descriptionPrefix, annotation)
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
proc parentDir*(path: Path): string {.borrow.}

func toLineAndCol(s: string; offset: Natural): tuple[line: int; col: int] =
  ## Returns the line and column number corresponding to the `offset` in `s`.
  result = (1, 1)
  for i, c in s:
    if i == offset:
      break
    elif c == '\n':
      inc result.line
      result.col = 0
    inc result.col

func tidyJsonyMessage*(jsonyMsg, fileContents: string): string =
  var jsonyMsgStart = ""
  var offset = -1
  # See https://github.com/treeform/jsony/blob/33c3daa/src/jsony.nim#L25-L27
  if jsonyMsg.scanf("$* At offset: $i$.", jsonyMsgStart, offset):
    let (line, col) = toLineAndCol(fileContents, offset)
    &"({line}, {col}): {jsonyMsgStart}"
  else:
    &": {jsonyMsg}"

proc tidyJsonyErrorMsg*(trackConfigContents: string): string =
  let jsonyMsg = getCurrentExceptionMsg()
  let details = tidyJsonyMessage(jsonyMsg, trackConfigContents)
  const bugNotice = """
    --------------------------------------------------------------------------------
    THIS IS A CONFIGLET BUG. PLEASE REPORT IT.

    The JSON parsing error above should not occur - it indicates a bug in configlet!

    If you are seeing this, please open an issue in this repo:
    https://github.com/exercism/configlet

    Please include:
    - a copy of the error message above
    - the contents of the track `config.json` file at the time `configlet lint` ran

    Thank you.
    --------------------------------------------------------------------------------
  """.unindent()
  result = &"JSON parsing error:\nconfig.json{details}\n\n{bugNotice}"

proc parseFile*(path: string; T: typedesc): T =
  ## Parses the JSON file at `path` into `T`.
  let contents =
    try:
      readFile(path)
    except IOError:
      let msg = getCurrentExceptionMsg()
      stderr.writeLine &"Error: {msg}"
      quit 1
  if contents.len > 0:
    try:
      contents.fromJson(T)
    except jsony.JsonError:
      let jsonyMsg = getCurrentExceptionMsg()
      let details = tidyJsonyMessage(jsonyMsg, contents)
      let msg = &"JSON parsing error:\n{path}{details}"
      stderr.writeLine msg
      quit 1
  else:
    T()
