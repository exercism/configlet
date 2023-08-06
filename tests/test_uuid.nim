import std/[sets, strformat, strutils, unittest]
import "."/[lint/validators, uuid/uuid]

proc main =
  suite "genUUID":
    const n = 10_000
    var uuids = initHashSet[Uuid](n)

    test &"can generate {insertSep($n)} valid version 4 UUIDs":
      for i in 1 .. n:
        let uuid = genUuid()
        check isUuidV4($uuid)
        uuids.incl uuid

    test "those UUIDs are distinct":
      check uuids.len == n

main()
{.used.}
