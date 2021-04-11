import std/unittest
import pkg/uuids
import "."/lint/validators

proc main =
  suite "genUUID: returns a string that isValidUuidV4 says is valid":
    test "1000 UUIDs":
      for i in 1 .. 1000:
        let uuid = $genUUID()
        check isValidUuidV4(uuid)

main()
{.used.}
