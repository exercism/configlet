import std/[macros, os, sequtils, strutils]
from ../patches/patch import gorgeCheck

proc getImports: NimNode =
  const files = block:
    const thisDir = currentSourcePath().parentDir()
    const cmd = "git -C \"" & thisDir & "\" ls-files" # Don't match pattern here.
    gorgeCheck(cmd, "command failed:\n" & cmd)
  result = nnkBracket.newTree()
  for f in files.splitLines():
    if f.startsWith("test_") and f.endsWith(".nim"):
      result.add ident(f[0..^5]) # Remove .nim file extension
  expectMinLen(result, 9)

macro importGitTrackedTestFiles =
  ## Imports every module in the current directory that is both:
  ## - tracked by `git`
  ## - and has a filename that matches `test_*.nim`
  let imports = getImports()
  result = quote do:
    import "."/`imports`
  echo "Combining these git-tracked test files:\n" & imports.toSeq().join("\n")

importGitTrackedTestFiles()
