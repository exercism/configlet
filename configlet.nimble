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
requires "nim >= 2.2.4"
requires "jsony"
requires "parsetoml"
requires "supersnappy"

task test, "Runs the test suite":
  if not fileExists("nimble.paths"):
    exec "nimble setup"
  exec "nim r ./tests/all_tests.nim"
