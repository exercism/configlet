import std/[os, osproc, strformat, strscans, strutils, unittest]
import exec, helpers, lint/validators, sync/probspecs
import "."/[binary_helpers]

proc main =
  suite "version":
    test "--version":
      let (outp, exitCode) = execCmdEx(&"{binaryPath} --version")
      var major, minor, patch: int
      check:
        outp.scanf("$i.$i.$i", major, minor, patch)
        exitCode == 0

main()
{.used.}
