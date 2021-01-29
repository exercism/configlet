import std/[algorithm, os]

template withDir*(dir: string; body: untyped): untyped =
  ## Changes the current directory to `dir` temporarily.
  let startDir = getCurrentDir()
  try:
    setCurrentDir(dir)
    body
  finally:
    setCurrentDir(startDir)

proc getSortedSubdirs*(dir: string): seq[string] =
  ## Returns a seq of the subdirectories of `dir`, in alphabetical order.
  result = newSeqOfCap[string](100)
  for kind, path in walkDir(dir):
    if kind == pcDir:
      result.add path
  sort result
