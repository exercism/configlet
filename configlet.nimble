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
requires "nim >= 1.6.12"
requires "cligen#b962cf8bc0be847cbc1b4f77952775de765e9689"      # 1.5.19 (2021-09-13)
requires "jsony#2a2cc4331720b7695c8b66529dbfea6952727e7b"       # 1.1.3  (2022-01-03)
requires "parsetoml#6e5e16179fa2db60f2f37d8b1af4128aaa9c8aaf"   # 0.7.1  (2023-08-06)
requires "supersnappy#e4df8cb5468dd96fc5a4764028e20c8a3942f16a" # 2.1.3  (2022-06-12)

task test, "Runs the test suite":
  exec "nim r ./tests/all_tests.nim"

before build:
  ensureThatNimblePackagesArePatched()
