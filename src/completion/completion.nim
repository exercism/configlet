import std/[os, strformat, syncio]
import pkg/supersnappy
import ../cli

proc readCompletions: array[Shell, string] =
  const repoRootDir = currentSourcePath().parentDir().parentDir().parentDir()
  const completionsDir = repoRootDir / "completions"
  for shell in sBash .. result.high:
    # When cross-compiling for Windows from Linux, replace the `\\` DirSep with `/`.
    var path = completionsDir / &"configlet.{shell}"
    when defined(windows) and defined(zig) and staticExec("uname") == "Linux":
      for c in path.mitems:
        if c == '\\':
          c = '/'
    result[shell] = staticRead(path).compress()

proc completion*(shellKind: Shell) =
  const completions = readCompletions()
  stdout.write completions[shellKind].uncompress()
