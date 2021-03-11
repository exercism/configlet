# Package
version       = "4.0.0"
author        = "ee7"
description   = "A tool for managing Exercism language track repositories"
license       = "AGPL-3.0-only"
srcDir        = "src"
bin           = @["configlet"]

# Dependencies
requires "nim >= 1.4.2"
requires "parsetoml"
requires "cligen"
requires "uuids >= 0.1.11"

task test, "Runs the test suite":
  exec "nim r ./tests/all_tests.nim"
