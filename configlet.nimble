import std/[hashes, os, strutils]

proc getVersionStart: string =
  # Returns the `major.minor.patch` version in the `configlet.version` file
  # (that is, omitting any pre-release version information).
  result = staticRead("configlet.version")
  for i, c in result:
    if c notin {'0'..'9', '.'}:
      result.setLen(i)
      return result

# Package
version       = getVersionStart() # Must consist only of digits and '.'
author        = "ee7"
description   = "A tool for managing Exercism language track repositories"
license       = "AGPL-3.0-only"
srcDir        = "src"
bin           = @["configlet"]

# Dependencies
requires "nim >= 1.6.6"
requires "cligen#b962cf8bc0be847cbc1b4f77952775de765e9689"    # 1.5.19 (2021-09-13)
requires "jsony#2a2cc4331720b7695c8b66529dbfea6952727e7b"     # 1.1.3  (2022-01-03)
requires "parsetoml#9cdeb3f65fd10302da157db8a8bac5c42f055249" # 0.6.0  (2021-06-07)
requires "uuids#8cb8720b567c6bcb261bd1c0f7491bdb5209ad06"     # 0.1.11 (2021-01-15)
# To make Nimble use the pinned `isaac` version, we must pin `isaac` after `uuids`
# (which has `isaac` as a dependency).
# Nimble still clones the latest `isaac` tag if there is no tag-versioned one
# on-disk (e.g. at ~/.nimble/pkgs/isaac-0.1.3), and adds it to the path when
# building, but (due to writing it later) the pinned version takes precedence.
# Nimble will support lock files in the future, which should provide more robust
# version pinning.
requires "isaac#45a5cbbd54ff59ba3ed94242620c818b9aad1b5b"     # 0.1.3  (2017-11-16)

task test, "Runs the test suite":
  exec "nim r ./tests/all_tests.nim"

# Patch `cligen/parseopt3` so that "--foo --bar" is parsed as two long options,
# even when `longNoVal` is both non-empty and lacks `foo`.
before build:
  # We want to support running `nimble build` before `cligen` is installed, so
  # we can't `import cligen/parseopt3` and check the parsing directly.
  # Instead, let's just hash the file and run `git apply` conditionally.
  # First, get the path to `parseopt3.nim` in the `cligen` package.
  let (output, exitCode) = gorgeEx("nimble path cligen")
  if exitCode == 0:
    let parseopt3Path = joinPath(output.strip(), "cligen", "parseopt3.nim")
    # Hash the file using `std/hashes`.
    # Note that we can't import `std/md5` or `std/sha1` in a .nimble file.
    let actualHash = parseopt3Path.readFile().hash()
    const patchedHash = 1647921161 # Update when bumping `cligen` changes `parseopt3`.
    if actualHash != patchedHash:
      let patchPath = thisDir() / "parseopt3_allow_long_option_optional_value.patch"
      let parseopt3Dir = parseopt3Path.parentDir()
      # Apply the patch.
      let cmd = "git -C " & parseopt3Dir & " apply --verbose " & patchPath
      let (outp, exitCode) = gorgeEx(cmd)
      echo outp
      if exitCode != 0:
        raise newException(OSError, "failed to apply patch")
  else:
    echo output
    raise newException(OSError, "failed to get cligen path")
