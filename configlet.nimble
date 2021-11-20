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

import std/[hashes, os, strutils]

before build:
  # Patch `cligen/parseopt3` so that "--foo --bar" is parsed as two long
  # options, even when `longNoVal` is both non-empty and lacks `foo`.
  # Get the path to `parseopt3.nim` in the `cligen` package.
  let (output, exitCode) = gorgeEx("nimble path cligen")
  if exitCode == 0:
    let parseopt3Path = joinPath(output.strip(), "cligen", "parseopt3.nim")
    if fileExists(parseopt3Path):
      let actualHash = parseopt3Path.readFile().hash()
      const patchedHash = 1647921161
      if actualHash != patchedHash:
        echo "Trying to patch parseopt3..."
        echo "Found " & parseopt3Path
        let patchPath = thisDir() / "parseopt3_allow_long_option_optional_value.patch"
        let parseopt3Dir = parseopt3Path.parentDir()
        let cmd = "git -C " & parseopt3Dir & " apply --verbose " & patchPath
        let (outp, exitCode) = gorgeEx(cmd)
        echo outp
        if exitCode != 0:
          raise newException(AssertionDefect, "failed to apply patch")
    else:
      raise newException(AssertionDefect, "file does not exist: " & parseopt3Path)
  else:
    echo output
    raise newException(AssertionDefect, "failed to get cligen path")
