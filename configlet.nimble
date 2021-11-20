# Package
version       = "4.0.0"
author        = "ee7"
description   = "A tool for managing Exercism language track repositories"
license       = "AGPL-3.0-only"
srcDir        = "src"
bin           = @["configlet"]

# Dependencies
requires "nim >= 1.6.0"
requires "parsetoml"
requires "cligen"
requires "uuids >= 0.1.11"
requires "jsony >= 1.0.4"

task test, "Runs the test suite":
  exec "nim r ./tests/all_tests.nim"

import std/os
import pkg/[cligen/parseopt3]

before build:
  # Check that "--foo --bar" is parsed as two long options, even when
  # `longNoVal` is both non-empty and lacks `foo`.
  # Otherwise, patch `cligen/parseopt3` to make that happen.
  func canParseOptionalValue: bool =
    const cmdLine = @["--foo", "--bar"]
    const longNoVal = @["bar"]
    var parsed = newSeq[(CmdLineKind, string, string)]()
    for kind, key, val in getopt(cmdLine = cmdLine, longNoVal = longNoVal):
      parsed.add (kind, key, val)
    const expected = @[(cmdLongOption, "foo", ""), (cmdLongOption, "bar", "")]
    if parsed == expected:
      result = true

  if not canParseOptionalValue():
    echo "Trying to patch parseopt3..."
    # Get the path to `parseopt3.nim` in the `cligen` package.
    let (cligenPath, exitCode) = gorgeEx("nimble path cligen")
    if exitCode == 0:
      let parseopt3Path = joinPath(cligenPath, "cligen", "parseopt3.nim")
      if fileExists(parseopt3Path):
        # Patch it.
        echo "Found " & parseopt3Path
        let patchPath = thisDir() / "parseopt3_allow_long_option_optional_value.patch"
        let cmd = "git -C " & quoteShell(parseopt3Path.parentDir()) & " apply --verbose " & quoteShell(patchPath)
        let (outp, exitCode) = gorgeEx(cmd)
        echo outp
        if exitCode != 0:
          raise newException(AssertionDefect, "failed to apply patch")
      else:
        raise newException(AssertionDefect, "file does not exist: " & parseopt3Path)
    else:
      echo cligenPath
      raise newException(AssertionDefect, "failed to get cligen path")
