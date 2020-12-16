# Package
version       = "0.1.0"
author        = "ee7"
description   = "A tool for managing Exercism language track repositories"
license       = "AGPL-3.0-only"
srcDir        = "src"
bin           = @["configlet"]

# Dependencies
requires "nim >= 1.4.0"
requires "parsetoml"
requires "cligen"
requires "uuids"
