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

func isValidUuidV4*(s: string): bool =
  ## Returns `true` if `s` is a valid version 4 UUID (compliant with RFC 4122)
  ## in the canonical textual representation.
  ##
  ## This func is equivalent to using `re.match` with the below regex pattern:
  ##
  ## `^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`
  ##
  ## However, this func's implementation is faster and doesn't add a PCRE
  ## dependency.
  const
    Hex = {'0'..'9', 'a'..'f'}
    Separator = '-'
    Version = '4'
    Variant = {'8', '9', 'a', 'b'}
  result =
    s.len == 36 and
    s[0] in Hex and
    s[1] in Hex and
    s[2] in Hex and
    s[3] in Hex and
    s[4] in Hex and
    s[5] in Hex and
    s[6] in Hex and
    s[7] in Hex and
    s[8] == Separator and
    s[9] in Hex and
    s[10] in Hex and
    s[11] in Hex and
    s[12] in Hex and
    s[13] == Separator and
    s[14] == Version and
    s[15] in Hex and
    s[16] in Hex and
    s[17] in Hex and
    s[18] == Separator and
    s[19] in Variant and
    s[20] in Hex and
    s[21] in Hex and
    s[22] in Hex and
    s[23] == Separator and
    s[24] in Hex and
    s[25] in Hex and
    s[26] in Hex and
    s[27] in Hex and
    s[28] in Hex and
    s[29] in Hex and
    s[30] in Hex and
    s[31] in Hex and
    s[32] in Hex and
    s[33] in Hex and
    s[34] in Hex and
    s[35] in Hex
