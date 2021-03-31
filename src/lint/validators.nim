import std/[json, os, sets, streams, strformat, strutils, unicode]
import ".."/helpers

func allTrue*(bools: openArray[bool]): bool =
  ## Returns true if every item in `bools` is `true`.
  result = true
  for b in bools:
    if not b:
      return false

func q*(s: string): string =
  if s.len > 0:
    &"'{s}'"
  else:
    "root"

func format(context, key: string): string =
  if context.len > 0:
    q(&"{context}.{key}")
  else:
    q(key)

proc hasKey(data: JsonNode; key, path: string; isRequired: bool;
            context = ""): bool =
  ## Returns true if `data` contains the key `key`. Otherwise, returns false
  ## and, if `isRequired` is true, prints an error message.
  if data.hasKey(key):
    result = true
  elif isRequired:
    result.setFalseAndPrint(&"Missing key: {format(context, key)}", path)

proc isObject*(data: JsonNode; context, path: string): bool =
  if data.kind == JObject:
    result = true
  else:
    result.setFalseAndPrint(&"Not an object: {q context}", path)

proc hasObject*(data: JsonNode; key, path: string; isRequired = true): bool =
  if data.hasKey(key, path, isRequired):
    result = isObject(data[key], key, path)
  elif not isRequired:
    result = true

proc hasValidRuneLength(s, key, path: string; maxLen: int): bool =
  ## Returns true if `s` has a rune length that does not exceed `maxLen`.
  result = true
  if s.len > maxLen:
    let sRuneLen = s.runeLen
    if sRuneLen > maxLen:
      const truncLen = 25
      let sTrunc = if sRuneLen > truncLen: s.runeSubStr(0, truncLen) else: s
      let msg = &"The value of `{key}` that starts with `{sTrunc}...` is " &
                &"{sRuneLen} characters, but must not exceed {maxLen} " &
                "characters"
      result.setFalseAndPrint(msg, path)

proc isUrlLike(s: string): bool =
  ## Returns true if `s` starts with `https://`, `http://` or `www`.
  # We probably only need simplistic URL checking, and we want to avoid using
  # Nim's stdlib regular expressions in order to avoid a dependency on PCRE.
  s.startsWith("https://") or s.startsWith("http://") or s.startsWith("www")

const
  emptySetOfStrings = initHashSet[string](0)

proc isString*(data: JsonNode; key, path: string; isRequired = true;
               allowed = emptySetOfStrings; checkIsUrlLike = false;
               maxLen = int.high; isInArray = false): bool =
  result = true
  case data.kind
  of JString:
    let s = data.getStr()
    if allowed.len > 0:
      if s notin allowed:
        let msgStart = &"The value of `{key}` is `{s}`, but it must be one of "
        let msgEnd =
          if allowed.len < 6:
            $allowed
          else:
            "the allowed values"
        result.setFalseAndPrint(msgStart & msgEnd, path)
    elif checkIsUrlLike:
      if not isUrlLike(s):
        result.setFalseAndPrint(&"Not a valid URL: {s}", path)
    elif s.len > 0:
      if not isEmptyOrWhitespace(s):
        if not hasValidRuneLength(s, key, path, maxLen):
          result = false
      else:
        let msg =
          if isInArray:
            &"The {q key} array contains a whitespace-only string"
          else:
            &"String is whitespace-only: {q key}"
        result.setFalseAndPrint(msg, path)
    else:
      let msg =
        if isInArray:
          &"The {q key} array contains a zero-length string"
        else:
          &"String is zero-length: {q key}"
      result.setFalseAndPrint(msg, path)
  of JNull:
    if isRequired:
      result.setFalseAndPrint(&"Value is `null`, but must be a string: {q key}",
                              path)
  else:
    let msg =
      if isInArray:
        &"The {q key} array contains a non-string: {data}"
      else:
        &"Not a string: {q key}: {data}"
    result.setFalseAndPrint(msg, path)

proc hasString*(data: JsonNode; key, path: string; isRequired = true;
                allowed = emptySetOfStrings; checkIsUrlLike = false;
                maxLen = int.high): bool =
  if data.hasKey(key, path, isRequired):
    result = isString(data[key], key, path, isRequired, allowed, checkIsUrlLike,
                      maxLen)
  elif not isRequired:
    result = true

proc isArrayOfStrings*(data: JsonNode;
                       context, key, path: string;
                       isRequired = true): bool =
  ## Returns true in any of these cases:
  ## - `data` is a non-empty `JArray` that contains only non-empty, non-blank
  ##   strings.
  ## - `data` is an empty `JArray` and `isRequired` is false.
  result = true

  case data.kind
  of JArray:
    if data.len > 0:
      for item in data:
        let k = if context.len > 0: &"{context}.{key}" else: key
        if not isString(item, k, path, isRequired, isInArray = true):
          result = false
    elif isRequired:
      result.setFalseAndPrint(&"Array is empty: {format(context, key)}", path)
  of JNull:
    if isRequired:
      result.setFalseAndPrint("Value is `null`, but must be an array: " &
                              format(context, key), path)
  else:
    result.setFalseAndPrint(&"Not an array: {format(context, key)}", path)

proc hasArrayOfStrings*(data: JsonNode;
                        context, key, path: string;
                        isRequired = true): bool =
  ## When `context` is the empty string, returns true in any of these cases:
  ## - `isArrayOfStrings` returns true for `data[key]`.
  ## - `data` lacks the key `key` and `isRequired` is false.
  ##
  ## When `context` is a non-empty string, returns true in any of these cases:
  ## - `isArrayOfStrings` returns true for `data[context][key]`.
  ## - `data[context]` lacks the key `key` and `isRequired` is false.
  let d = if context.len > 0: data[context] else: data
  if d.hasKey(key, path, isRequired, context):
    result = isArrayOfStrings(d[key], context, key, path, isRequired)
  elif not isRequired:
    result = true

proc isArrayOf*(data: JsonNode;
                context, path: string;
                call: proc(d: JsonNode; key, path: string): bool;
                isRequired = true,
                allowedLength: Slice): bool =
  ## Returns true in any of these cases:
  ## - `data` is a non-empty `JArray` and `call` returns true for each of its
  ##   items.
  ## - `data` is an empty `JArray` and `isRequired` is false.
  result = true

  case data.kind
  of JArray:
    let arrayLen = data.len
    if arrayLen > 0:
      if arrayLen in allowedLength:
        for item in data:
          if not call(item, context, path):
            result = false
      else:
        let msgStart = &"The `{context}` array has length {arrayLen}, " &
                        "but must have length "
        let msgEnd =
          if allowedLength.len == 1:
            &"of exactly {allowedLength.a}"
          else:
            &"between {allowedLength.a} and {allowedLength.b} (inclusive)"
        result.setFalseAndPrint(msgStart & msgEnd, path)

    elif isRequired:
      result.setFalseAndPrint(&"Array is empty: {q context}", path)
  of JNull:
    if isRequired:
      result.setFalseAndPrint("Value is `null`, but must be an array: " &
                              q(context), path)
  else:
    result.setFalseAndPrint(&"Not an array: {q context}", path)

proc hasArrayOf*(data: JsonNode;
                 key, path: string;
                 call: proc(d: JsonNode; key, path: string): bool;
                 isRequired = true,
                 allowedLength: Slice = 0..int.high): bool =
  ## Returns true in any of these cases:
  ## - `isArrayOf` returns true for `data[key]`.
  ## - `data` lacks the key `key` and `isRequired` is false.
  if data.hasKey(key, path, isRequired):
    result = isArrayOf(data[key], key, path, call, isRequired, allowedLength)
  elif not isRequired:
    result = true

proc isBoolean*(data: JsonNode; key, path: string; isRequired = true): bool =
  result = true
  case data.kind
  of JBool:
    return true
  of JNull:
    if isRequired:
      result.setFalseAndPrint(&"Value is `null`, but must be a bool: {q key}",
                              path)
  else:
    result.setFalseAndPrint(&"Not a bool: {q key}: {data}", path)

proc hasBoolean*(data: JsonNode; key, path: string; isRequired = true): bool =
  if data.hasKey(key, path, isRequired):
    result = isBoolean(data[key], key, path, isRequired)
  elif not isRequired:
    result = true

proc isInteger*(data: JsonNode; key, path: string; isRequired = true;
                allowed: Slice): bool =
  result = true
  case data.kind
  of JInt:
    let num = data.getInt()
    if num notin allowed:
      let msgStart = &"The value of `{key}` is `{num}`, but it must be "
      let msgEnd =
        if allowed.len == 1:
          &"`{allowed.a}`"
        else:
          &"between {allowed.a} and {allowed.b} (inclusive)"
      result.setFalseAndPrint(msgStart & msgEnd, path)
  of JNull:
    if isRequired:
      result.setFalseAndPrint("Value is `null`, but must be an integer: " &
                              q(key), path)
  else:
    result.setFalseAndPrint(&"Not an integer: {q key}: {data}", path)

proc hasInteger*(data: JsonNode; key, path: string; isRequired = true;
                 allowed: Slice): bool =
  if data.hasKey(key, path, isRequired):
    result = isInteger(data[key], key, path, isRequired, allowed)
  elif not isRequired:
    result = true

proc subdirsContain*(dir: string, files: openArray[string]): bool =
  ## Returns `true` if every file in `files` exists in every subdirectory of
  ## `dir`.
  ##
  ## Returns `true` if `dir` does not exist or has no subdirectories.
  result = true

  if dirExists(dir):
    for subdir in getSortedSubdirs(dir):
      for file in files:
        let path = subdir / file
        if not fileExists(path):
          result.setFalseAndPrint("Missing file", path)

proc parseJsonFile*(path: string, b: var bool, allowEmptyArray = false): JsonNode =
  ## Parses the file at `path` and returns the resultant JsonNode.
  ##
  ## Sets `b` to false if unsuccessful.
  if fileExists(path):
    let contents = readFile(path)
    if not isEmptyOrWhitespace(contents):
      try:
        result = parseJson(newStringStream(contents), path)
      except JsonParsingError:
        b.setFalseAndPrint("JSON parsing error", getCurrentExceptionMsg())
    else:
      let msg =
        if allowEmptyArray:
          ", but must contain at least the empty array, `[]`"
        else:
          ""
      b.setFalseAndPrint("File is empty" & msg, path)
  else:
    b.setFalseAndPrint("Missing file", path)
