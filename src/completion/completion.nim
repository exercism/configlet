import std/[os, strformat, syncio]
import pkg/supersnappy
import ../cli

proc readCompletions: array[Shell, string] =
  const repoRootDir = currentSourcePath().parentDir().parentDir().parentDir()
  const completionsDir = repoRootDir / "completions"
  for shell in sBash .. result.high:
    result[shell] = staticRead(completionsDir / &"configlet.{shell}").compress()

proc completion*(shellKind: Shell) =
  const completions = readCompletions()
  stdout.write completions[shellKind].uncompress()
