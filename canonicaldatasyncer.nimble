# Package
version       = "0.4.0"
author        = "Erik Schierboom"
description   = "Sync canonical data from the Problem Specifications repo to the track repo"
license       = "AGPL3"
srcDir        = "src"
bin           = @["canonicaldatasyncer"]

backend       = "c"

# Dependencies
requires "nim >= 1.2.6"
requires "parsetoml"
