# Package
version       = "0.1.0"
author        = "ee7"
description   = "A tool for managing Exercism language track repositories"
license       = "AGPL-3.0-only"
srcDir        = "src"

namedBin["configlet"] = "configlet_v3" # Adds `_v3` to the binary filename for now.
                                       # Replace with `bin = @["configlet"]` later.
# Dependencies
requires "nim >= 1.4.0"
requires "parsetoml"
requires "cligen"
