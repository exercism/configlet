import std/[strformat, sysrand]
import ".."/logger

type
  Uuid = array[16, byte]

proc genUuid*: Uuid {.noinit.} =
  ## Returns a version 4 UUID, using the system CSPRNG as the source of randomness.
  if urandom(result):
    result[6] = (result[6] and 0x0f) or 0x40 # Set version to 4
    result[8] = (result[8] and 0x3f) or 0x80 # Set variant to 1
  else:
    stderr.writeLine "uuid: error: failed to generate UUID"
    quit 1

func `$`*(u: Uuid): string =
  ## Returns the canonical string representation for the given UUID `u`.
  result = newString(36)
  result[8] = '-'
  result[13] = '-'
  result[18] = '-'
  result[23] = '-'
  for i, j in [0, 2, 4, 6, 9, 11, 14, 16, 19, 21, 24, 26, 28, 30, 32, 34]:
    const hex = "0123456789abcdef"
    result[j + 0] = hex[u[i] shr 4]
    result[j + 1] = hex[u[i] and 0x0f]

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
