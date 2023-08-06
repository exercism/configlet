import std/[strformat, random, sysrand]
import ".."/logger

type
  Uuid* = array[16, byte]

var r = block:
  var seed: array[8, byte]
  if not urandom(seed):
    stderr.writeLine "uuid: error: failed to generate UUID"
    quit 1
  initRand(cast[int64](seed))

proc genUuid*: Uuid {.noinit.} =
  ## Returns a version 4 UUID, using the system CSPRNG as the source of randomness.
  var a = rand(r, uint32.high) # Can't use uint64.high
  copyMem(result[0].addr, a.addr, 4)
  a = rand(r, uint32.high)
  copyMem(result[4].addr, a.addr, 4)
  a = rand(r, uint32.high)
  copyMem(result[8].addr, a.addr, 4)
  a = rand(r, uint32.high)
  copyMem(result[12].addr, a.addr, 4)
  result[6] = (result[6] and 0x0f) or 0x40 # Set version to 4
  result[8] = (result[8] and 0x3f) or 0x80 # Set variant to 1

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
