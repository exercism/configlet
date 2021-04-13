import std/strformat
import pkg/uuids
import ".."/logger

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
    s.add $genUUID()
    s.add '\n'
  stdout.write s

proc uuid*(n: Positive) =
  outputUuids(n)
