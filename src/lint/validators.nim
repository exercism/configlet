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
    &"`{s}`"
  else:
    "root"

func joinWithDot(context, key: string): string =
  if context.len > 0:
    &"{context}.{key}"
  else:
    key

const
  qNull* = q("null") # So we don't have to write &"""Foo is {q "null"}""" later

func format*(context, key: string): string =
  if context.len > 0:
    q(&"{context}.{key}")
  else:
    q(key)

proc hasKey(data: JsonNode; key: string; path: Path; context: string;
            isRequired: bool): bool =
  ## Returns true if `data` contains the key `key`. Otherwise, returns false
  ## and, if `isRequired` is true, prints an error message.
  if data.hasKey(key):
    result = true
  elif isRequired:
    result.setFalseAndPrint(&"The {format(context, key)} key is missing", path)

proc isObject*(data: JsonNode; key: string; path: Path; context = ""): bool =
  if data.kind == JObject:
    result = true
  else:
    result.setFalseAndPrint(&"The value of {format(context, key)} is not an object",
                            path)

proc hasObject*(data: JsonNode; key: string; path: Path; context = "";
                isRequired = true): bool =
  if data.hasKey(key, path, context, isRequired):
    result = isObject(data[key], key, path)
  elif not isRequired:
    result = true

proc hasValidRuneLength(s, key: string; path: Path; context: string;
                        maxLen: int): bool =
  ## Returns true if `s` has a rune length that does not exceed `maxLen`.
  result = true
  if s.len > maxLen:
    let sRuneLen = s.runeLen
    if sRuneLen > maxLen:
      const truncLen = 25
      let sTrunc = if sRuneLen > truncLen: s.runeSubStr(0, truncLen) else: s
      let msg = &"The value of {format(context, key)} that starts with " &
                &"{q sTrunc}... is {sRuneLen} characters, but it must not " &
                &"exceed {maxLen} characters"
      result.setFalseAndPrint(msg, path)

proc isUrlLike(s: string): bool =
  ## Returns true if `s` starts with `https://`, `http://` or `www`.
  # We probably only need simplistic URL checking, and we want to avoid using
  # Nim's stdlib regular expressions in order to avoid a dependency on PCRE.
  s.startsWith("https://") or s.startsWith("http://") or s.startsWith("www")

const
  emptySetOfStrings = initHashSet[string](0)

func isLowerKebab(s: string): bool =
  ## Returns true if `s` is a lowercase and kebab-case string.
  result = true
  for c in s:
    if c notin {'a'..'z', '0'..'9', '-'}:
      return false

proc isString*(data: JsonNode; key: string; path: Path; context: string;
               isRequired = true; allowed = emptySetOfStrings;
               checkIsUrlLike = false; maxLen = int.high; checkIsKebab = false;
               isInArray = false): bool =
  result = true
  case data.kind
  of JString:
    let s = data.getStr()
    if allowed.len > 0:
      if s notin allowed:
        let msgStart =
          if isInArray:
            &"The {format(context, key)} array contains {q s}, which is not one of "
          else:
            &"The value of {format(context, key)} is {q s}, but it must be one of "
        let msgEnd =
          if allowed.len < 6:
            $allowed
          else:
            "the allowed values"
        result.setFalseAndPrint(msgStart & msgEnd, path)
    elif checkIsUrlLike:
      if not isUrlLike(s):
        result.setFalseAndPrint(&"Not a valid URL: {q s}", path)
    elif s.len > 0:
      if not isEmptyOrWhitespace(s):
        if checkIsKebab:
          if not isLowerKebab(s):
            let msg =
              if isInArray:
                &"The {format(context, key)} array contains {s}, but every " &
                 "value must be lowercase and kebab-case"
              else:
                &"The {format(context, key)} value is {s}, but it must be a " &
                "lowercase and kebab-case string"
            result.setFalseAndPrint(msg, path)
        if not hasValidRuneLength(s, key, path, context, maxLen):
          result = false
      else:
        let msg =
          if isInArray:
            &"The {format(context, key)} array contains a whitespace-only string"
          else:
            &"The value of {format(context, key)} is a whitespace-only string"
        result.setFalseAndPrint(msg, path)
    else:
      let msg =
        if isInArray:
          &"The {format(context, key)} array contains a zero-length string"
        else:
          &"The value of {format(context, key)} is a zero-length string"
      result.setFalseAndPrint(msg, path)
  of JNull:
    if isRequired:
      result.setFalseAndPrint(&"The value of {format(context, key)} is {qNull}, " &
                               "but it must be a string", path)
  else:
    let msg =
      if isInArray:
        &"The {format(context, key)} array contains a non-string: {q $data}"
      else:
        &"The value of {format(context, key)} is {q $data}, but it must be a string"
    result.setFalseAndPrint(msg, path)

proc hasString*(data: JsonNode; key: string; path: Path; context = "";
                isRequired = true; allowed = emptySetOfStrings;
                checkIsUrlLike = false; maxLen = int.high;
                checkIsKebab = false): bool =
  if data.hasKey(key, path, context, isRequired):
    result = isString(data[key], key, path, context, isRequired, allowed,
                      checkIsUrlLike, maxLen, checkIsKebab = checkIsKebab)
  elif not isRequired:
    result = true

proc isArrayOfStrings*(data: JsonNode;
                       context: string;
                       path: Path;
                       isRequired = true;
                       allowed: HashSet[string];
                       allowedArrayLen: Slice;
                       checkIsKebab: bool): bool =
  ## Returns true in any of these cases:
  ## - `data` is a `JArray` with length in `allowedArrayLen` that contains only
  ##   non-empty, non-blank strings.
  ## - `data` is an empty `JArray` and `isRequired` is false.
  result = true

  case data.kind
  of JArray:
    let arrayLen = data.len
    if arrayLen > 0:
      if arrayLen in allowedArrayLen:
        for item in data:
          if not isString(item, context, path, "", isRequired, allowed,
                          checkIsKebab = checkIsKebab, isInArray = true):
            result = false
      else:
        let msgStart = &"The {q context} array has length {arrayLen}, " &
                        "but it must have length "
        let msgEnd =
          if allowedArrayLen.len == 1:
            &"of exactly {allowedArrayLen.a}"
          else:
            &"between {allowedArrayLen.a} and {allowedArrayLen.b} (inclusive)"
    elif isRequired:
      if 0 notin allowedArrayLen:
        result.setFalseAndPrint(&"The {q context} array is empty", path)
  of JNull:
    if isRequired:
      result.setFalseAndPrint(&"The value of {q context} is " &
                              &"{qNull}, but it must be an array", path)
  else:
    result.setFalseAndPrint(&"The value of {q context} is " &
                             "not an array", path)

proc hasArrayOfStrings*(data: JsonNode;
                        key: string;
                        path: Path;
                        context = "";
                        isRequired = true;
                        allowed = emptySetOfStrings;
                        allowedArrayLen = 1..int.high;
                        checkIsKebab = false): bool =
  ## Returns true in any of these cases:
  ## - `isArrayOfStrings` returns true for `data[key]`.
  ## - `data` lacks the key `key` and `isRequired` is false.
  if data.hasKey(key, path, context, isRequired):
    let contextAndKey = joinWithDot(context, key)
    result = isArrayOfStrings(data[key], contextAndKey, path, isRequired,
                              allowed, allowedArrayLen, checkIsKebab = checkIsKebab)
  elif not isRequired:
    result = true

type
  ItemCall = proc(data: JsonNode; context: string; path: Path): bool {.nimcall.}

proc isArrayOf*(data: JsonNode;
                context: string;
                path: Path;
                call: ItemCall;
                isRequired = true;
                allowedLength: Slice): bool =
  ## Returns true in any of these cases:
  ## - `data` is a `JArray` with length in `allowedLength`, and `call` returns
  ##   true for each of its items.
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
        let msgStart = &"The {q context} array has length {arrayLen}, " &
                        "but it must have length "
        let msgEnd =
          if allowedLength.len == 1:
            &"of exactly {allowedLength.a}"
          else:
            &"between {allowedLength.a} and {allowedLength.b} (inclusive)"
        result.setFalseAndPrint(msgStart & msgEnd, path)

    elif isRequired:
      if 0 notin allowedLength:
        result.setFalseAndPrint(&"Array is empty: {q context}", path)
  of JNull:
    if isRequired:
      result.setFalseAndPrint(&"The value of {q context} is {qNull}, " &
                               "but it must be an array", path)
  else:
    result.setFalseAndPrint(&"The value of {q context} is not an array", path)

proc hasArrayOf*(data: JsonNode;
                 key: string;
                 path: Path;
                 call: ItemCall;
                 context = "";
                 isRequired = true;
                 allowedLength: Slice = 1..int.high): bool =
  ## Returns true in any of these cases:
  ## - `isArrayOf` returns true for `data[key]`.
  ## - `data` lacks the key `key` and `isRequired` is false.
  if data.hasKey(key, path, context, isRequired):
    let contextAndKey = joinWithDot(context, key)
    result = isArrayOf(data[key], contextAndKey, path, call, isRequired,
                       allowedLength)
  elif not isRequired:
    result = true

proc isBoolean*(data: JsonNode; key: string; path: Path; context: string;
                isRequired = true): bool =
  result = true
  case data.kind
  of JBool:
    return true
  of JNull:
    if isRequired:
      result.setFalseAndPrint(&"The value of {format(context, key)} is {qNull}, " &
                               "but it must be a bool", path)
  else:
    result.setFalseAndPrint(&"The value of {format(context, key)} is {q $data}, " &
                             "but it must be a bool", path)

proc hasBoolean*(data: JsonNode; key: string; path: Path; context = "";
                 isRequired = true): bool =
  if data.hasKey(key, path, context, isRequired):
    result = isBoolean(data[key], key, path, context, isRequired)
  elif not isRequired:
    result = true

proc isInteger*(data: JsonNode; key: string; path: Path; context: string;
                isRequired = true; allowed: Slice): bool =
  result = true
  case data.kind
  of JInt:
    let num = data.getInt()
    if num notin allowed:
      let msgStart = &"The value of {format(context, key)} is {num}, but it must be "
      let msgEnd =
        if allowed.len == 1:
          &"{allowed.a}"
        else:
          &"between {allowed.a} and {allowed.b} (inclusive)"
      result.setFalseAndPrint(msgStart & msgEnd, path)
  of JNull:
    if isRequired:
      result.setFalseAndPrint(&"The value of {format(context, key)} is {qNull}, " &
                               "but it must be an integer", path)
  else:
    result.setFalseAndPrint(&"The value of {format(context, key)} is {q $data}, " &
                             "but it must be an integer", path)

proc hasInteger*(data: JsonNode; key: string; path: Path; context = "";
                 isRequired = true; allowed: Slice): bool =
  if data.hasKey(key, path, context, isRequired):
    result = isInteger(data[key], key, path, context, isRequired, allowed)
  elif not isRequired:
    result = true

proc dirExists*(path: Path): bool {.borrow.}
proc fileExists(path: Path): bool {.borrow.}
proc readFile(path: Path): string {.borrow.}
proc parseJson(s: Stream; filename: Path; rawIntegers = false;
               rawFloats = false): JsonNode {.borrow.}

proc subdirsContain*(dir: Path; files: openArray[string]): bool =
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

proc parseJsonFile*(path: Path; b: var bool;
                    allowEmptyArray = false): JsonNode =
  ## Parses the file at `path` and returns the resultant JsonNode.
  ##
  ## Sets `b` to false if unsuccessful.
  if fileExists(path):
    let contents = readFile(path)
    if not isEmptyOrWhitespace(contents):
      try:
        result = parseJson(newStringStream(contents), path)
      except JsonParsingError:
        # Workaround: Convert to `Path` to satisfy current `setFalseAndPrint`.
        let msg = Path(getCurrentExceptionMsg())
        b.setFalseAndPrint("JSON parsing error", msg)
    else:
      let msg =
        if allowEmptyArray:
          &""", but must contain at least the empty array, {q "[]"}"""
        else:
          ""
      b.setFalseAndPrint("File is empty" & msg, path)
  else:
    b.setFalseAndPrint("Missing file", path)
