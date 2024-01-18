import std/[macros, os]
import helpers

proc genBracket: NimNode =
  const thisDir = currentSourcePath().parentDir().Path()
  const files = thisDir.getSortedFiles(relative = true, "test_$[w].nim$.")
  result = nnkBracket.newTree()
  for f in files:
    result.add ident(f.string[0..^5]) # Remove .nim file extension.
  expectMinLen(result, 8)

macro importTestFiles =
  ## Imports every Nim module that begins with `test_` in the parent directory.
  let bracket = genBracket()
  result = newStmtList(quote do:
    import "."/`bracket`)
  echo "all_tests: 'importTestFiles' produced:\n" & result.repr

importTestFiles()
