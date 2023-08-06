import std/[sets, strformat, strutils, unittest]
import "."/[lint/validators, uuid/uuid]

proc main =
  suite "genUUID":
    const n = 1_000
    var uuids = initHashSet[string](n)

    test &"can generate {insertSep($n)} valid version 4 UUIDs":
      for i in 1 .. n:
        let uuid = $genUuid()
        uuids.incl uuid
        check isUuidV4(uuid)

    test "those UUIDs are distinct":
      check uuids.len == n

main()
{.used.}
