import patches/patch

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
requires "nim >= 1.6.10"
requires "cligen#b962cf8bc0be847cbc1b4f77952775de765e9689"      # 1.5.19 (2021-09-13)
requires "jsony#2a2cc4331720b7695c8b66529dbfea6952727e7b"       # 1.1.3  (2022-01-03)
requires "parsetoml#9cdeb3f65fd10302da157db8a8bac5c42f055249"   # 0.6.0  (2021-06-07)
requires "supersnappy#e4df8cb5468dd96fc5a4764028e20c8a3942f16a" # 2.1.3  (2022-06-12)
requires "uuids#8cb8720b567c6bcb261bd1c0f7491bdb5209ad06"       # 0.1.11 (2021-01-15)
# To make Nimble use the pinned `isaac` version, we must pin `isaac` after `uuids`
# (which has `isaac` as a dependency).
# Nimble still clones the latest `isaac` tag if there is no tag-versioned one
# on-disk (e.g. at ~/.nimble/pkgs/isaac-0.1.3), and adds it to the path when
# building, but (due to writing it later) the pinned version takes precedence.
# Nimble will support lock files in the future, which should provide more robust
# version pinning.
requires "isaac#45a5cbbd54ff59ba3ed94242620c818b9aad1b5b"       # 0.1.3  (2017-11-16)

task test, "Runs the test suite":
  exec "nim r ./tests/all_tests.nim"

before build:
  ensureThatNimblePackagesArePatched()
