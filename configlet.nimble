import std/[hashes, os, parseutils, strutils]

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

proc gorgeCheck(cmd, errorMsg: string): string =
  ## Executes `cmd` at compile time and returns its text output (stdout + stderr).
  ##
  ## Raises an exception if the exit code is non-zero, using the given `errorMsg`.
  var exitCode = -1
  (result, exitCode) = gorgeEx(cmd)
  result.stripLineEnd()
  if exitCode != 0:
    echo result
    raise newException(OSError, errorMsg)

type
  PackagePaths = object
    cligen: string

proc init(T: typedesc[PackagePaths]): T =
  ## Returns the absolute paths to Nimble packages that we patch.
  # Optimization: call `nimble path` only once.
  result = T()
  let output = block:
    var cmd = "nimble path"
    for fieldName, _ in result.fieldPairs:
      cmd.add " " & fieldName
    gorgeCheck(cmd, "failed to get path to packages")
  var i = 0
  for fieldVal in result.fields:
    i += output.parseUntil(fieldVal, {'\n'}, i) + 1

proc patch(dir, patchPath: string;
           files: varargs[tuple[relPath: string, patchedHash: int64]]) =
  ## Checks that each file in `files` has the corresponding `patchedHash`, and
  ## if not, applies the patch at `patchPath` to `dir`.
  ##
  ## Raises an exception if the patch could not be applied.
  # We want to support running `nimble build` before the package is installed,
  # so we can't `import foo` to check the package's behavior directly.
  # Instead, hash the files and then run `git apply` when necessary.
  # Use `std/hashes` to hash - note that we can't import `std/md5` or `std/sha1`
  # in a .nimble file.
  for (relPath, patchedHash) in files:
    if readFile(dir / relPath).hash().int64 != patchedHash:
      # Apply the patch.
      let cmd = "git -C " & dir & " apply --verbose " & patchPath
      exec cmd
      break

before build:
  # Patch `cligen/parseopt3` so that "--foo --bar" is parsed as two long options,
  # even when `longNoVal` is both non-empty and lacks `foo`.
  let packagePaths = PackagePaths.init()
  patch(
    packagePaths.cligen,
    thisDir() / "parseopt3_allow_long_option_optional_value.patch",
    ("cligen" / "parseopt3.nim", 1647921161'i64)
  )
