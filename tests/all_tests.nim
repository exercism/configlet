import std/[algorithm, macros, os, strutils]

proc getSortedTestFiles(dir: string): seq[string] =
  result = @[]
  # Note that we cannot use `walkFiles` or `walkPattern` at compile time.
  for kind, path in walkDir(dir, relative = true):
    if kind == pcFile:
      if path.startsWith("test_") and path.endsWith(".nim"):
        result.add path[0..^5] # Remove .nim file extension.
  sort result

macro importTestFiles =
  ## Imports every Nim module that begins with `test_` in the parent directory.
  const files = currentSourcePath().parentDir().getSortedTestFiles()
  var bracket = nnkBracket.newTree()
  for f in files:
    bracket.add ident(f)
  expectMinLen(bracket, 9)
  result = newStmtList(quote do:
    import "."/`bracket`)
  echo "all_tests: 'importTestFiles' produced:\n" & result.repr

importTestFiles()
