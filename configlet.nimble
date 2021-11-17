# Package
version       = "4.0.0"
author        = "ee7"
description   = "A tool for managing Exercism language track repositories"
license       = "AGPL-3.0-only"
srcDir        = "src"
bin           = @["configlet"]

# Dependencies
requires "nim >= 1.6.0"
requires "parsetoml == 0.6.0"
requires "cligen == 1.5.19"
requires "uuids == 0.1.11"
requires "isaac == 0.1.3"
requires "jsony == 1.1.1"

task test, "Runs the test suite":
  exec "nim r ./tests/all_tests.nim"
