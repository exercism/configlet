import std/[osproc, strformat, strutils, unittest]
import lint/validators
import "."/[binary_helpers]

proc main =
  suite "uuid":
    for cmd in ["uuid", "uuid -n 100", &"uuid -vq -n {repeat('9', 50)}"]:
      test &"{cmd}":
        let (outp, exitCode) = execCmdEx(&"{binaryPath} {cmd}")
        check exitCode == 0
        for line in outp.strip.splitLines:
          check line.isUuidV4

main()
{.used.}
