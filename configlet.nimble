# Package
version       = "4.0.0"
author        = "ee7"
description   = "A tool for managing Exercism language track repositories"
license       = "AGPL-3.0-only"
srcDir        = "src"
bin           = @["configlet"]

# Dependencies
requires "nim >= 1.6.0"
requires "cligen#b962cf8bc0be847cbc1b4f77952775de765e9689"    # 1.5.19 (2021-09-13)
requires "isaac#45a5cbbd54ff59ba3ed94242620c818b9aad1b5b"     # 0.1.3  (2017-11-16)
requires "jsony#eb63a326b7f16537764c090f8859eb2451ad8d4d"     # 1.1.1  (2021-11-16)
requires "parsetoml#9cdeb3f65fd10302da157db8a8bac5c42f055249" # 0.6.0  (2021-06-07)
requires "uuids#8cb8720b567c6bcb261bd1c0f7491bdb5209ad06"     # 0.1.11 (2021-01-15)

task test, "Runs the test suite":
  exec "nim r ./tests/all_tests.nim"
