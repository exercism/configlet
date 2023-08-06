import std/[strformat, sysrand]
import ".."/logger

type
  Uuid = object
    bytes: array[16, byte]

proc genUuid*: Uuid =
  ## Returns a version 4 UUID, using the system CSPRNG as the source of randomness.
  result = Uuid()
  if urandom(result.bytes):
    result.bytes[6] = (result.bytes[6] and 0x0f) or 0x40 # Set version to 4
    result.bytes[8] = (result.bytes[8] and 0x3f) or 0x80 # Set variant to 1
  else:
    stderr.writeLine "uuid: error: failed to generate UUID"
    quit 1

func addHex(s: var string, bytes: openArray[byte]) =
  ## Appends the hex string representation of each item in `bytes` to `s`.
  for b in bytes:
    s.add &"{b:02x}"

func `$`*(u: Uuid): string =
  ## Returns the canonical string representation for the given UUID `u`.
  result = newStringOfCap(36)
  result.addHex u.bytes.toOpenArray(0, 3)
  result.add '-'
  result.addHex u.bytes.toOpenArray(4, 5)
  result.add '-'
  result.addHex u.bytes.toOpenArray(6, 7)
  result.add '-'
  result.addHex u.bytes.toOpenArray(8, 9)
  result.add '-'
  result.addHex u.bytes.toOpenArray(10, 15)

proc outputUuids(n: Positive) =
  ## Writes `n` version 4 UUIDs to stdout. Writes only 1000 UUIDs if `n` is
  ## greater than 1000.
  const maxNumUuids = 1000
  if n > maxNumUuids:
    logNormal &"The UUID output limit is {maxNumUuids}, but {n} UUIDs were requested."
    logNormal &"Outputting {maxNumUuids} UUIDs:"
  let numUuidsToGenerate = min(n, maxNumUuids)
  var s = newStringOfCap(numUuidsToGenerate * 37)
  for i in 1 .. numUuidsToGenerate:
    s.add $genUuid()
    s.add '\n'
  stdout.write s

proc uuid*(n: Positive) =
  outputUuids(n)
