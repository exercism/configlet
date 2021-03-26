import std/[json, os, streams, strutils]
import std/unicode except strip
import ".."/helpers

func q(s: string): string =
  if s.len > 0:
    "'" & s & "'"
  else:
    "root"

proc isObject*(data: JsonNode; context, path: string): bool =
  result = true
  if data.kind != JObject:
    result.setFalseAndPrint("Not an object: " & q(context), path)

proc hasObject*(data: JsonNode; key, path: string; isRequired = true): bool =
  result = true
  if data.hasKey(key):
    if data[key].kind != JObject:
      result.setFalseAndPrint("Not an object: " & q(key), path)
  elif isRequired:
    result.setFalseAndPrint("Missing key: " & q(key), path)

proc hasValidRuneLength(s, key, path: string; maxLen: int): bool =
  ## Returns true if `s` has a rune length that does not exceed `maxLen`.
  result = true
  if s.len > maxLen:
    let sRuneLen = s.runeLen
    if sRuneLen > maxLen:
      const truncLen = 25
      let sTrunc = if sRuneLen > truncLen: s.runeSubStr(0, truncLen) else: s
      let msg = "The value of `" & key & "` that starts with `" & sTrunc &
                "...` is " & $sRuneLen & " characters, but must not exceed " &
                $maxLen & " characters"
      result.setFalseAndPrint(msg, path)

proc checkString*(data: JsonNode; key, path: string; isRequired = true,
                  maxLen = int.high): bool =
  result = true
  if data.hasKey(key):
    case data[key].kind
    of JString:
      let s = data[key].getStr()
      if s.len > 0:
        if s.strip().len > 0:
          if not hasValidRuneLength(s, key, path, maxLen):
            result = false
        else:
          result.setFalseAndPrint("String is whitespace-only: " & q(key), path)
      else:
        result.setFalseAndPrint("String is zero-length: " & q(key), path)
    of JNull:
      if isRequired:
        result.setFalseAndPrint("Value is `null`, but must be a string: " &
                                q(key), path)
    else:
      result.setFalseAndPrint("Not a string: " & q(key) & ": " & $data[key], path)
  elif isRequired:
    result.setFalseAndPrint("Missing key: " & q(key), path)

func format(context, key: string): string =
  if context.len > 0:
    q(context & "." & key)
  else:
    q(key)

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
        if item.kind == JString:
          let s = item.getStr()
          if s.len > 0:
            if s.strip().len == 0:
              result.setFalseAndPrint("Array contains whitespace-only string: " &
                                      format(context, key), path)
          else:
            result.setFalseAndPrint("Array contains zero-length string: " &
                                    format(context, key), path)
        else:
          result.setFalseAndPrint("Array contains non-string: " &
                                  format(context, key) & ": " & $item, path)
    elif isRequired:
      result.setFalseAndPrint("Array is empty: " & format(context, key), path)
  of JNull:
    if isRequired:
      result.setFalseAndPrint("Value is `null`, but must be an array: " &
                              format(context, key), path)
  else:
    result.setFalseAndPrint("Not an array: " & format(context, key), path)

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
  result = true
  let d = if context.len > 0: data[context] else: data

  if d.hasKey(key):
    if not isArrayOfStrings(d[key], context, key, path, isRequired):
      result = false
  elif isRequired:
    result.setFalseAndPrint("Missing key: " & format(context, key), path)

proc isArrayOf*(data: JsonNode;
                context, path: string;
                call: proc(d: JsonNode; key, path: string): bool;
                isRequired = true): bool =
  ## Returns true in any of these cases:
  ## - `data` is a non-empty `JArray` and `call` returns true for each of its
  ##   items.
  ## - `data` is an empty `JArray` and `isRequired` is false.
  result = true

  case data.kind
  of JArray:
    if data.len > 0:
      for item in data:
        if not call(item, context, path):
          result = false
    elif isRequired:
      result.setFalseAndPrint("Array is empty: " & q(context), path)
  of JNull:
    if isRequired:
      result.setFalseAndPrint("Value is `null`, but must be an array: " &
                              q(context), path)
  else:
    result.setFalseAndPrint("Not an array: " & q(context), path)

proc hasArrayOf*(data: JsonNode;
                 key, path: string;
                 call: proc(d: JsonNode; key, path: string): bool;
                 isRequired = true): bool =
  ## Returns true in any of these cases:
  ## - `isArrayOf` returns true for `data[key]`.
  ## - `data` lacks the key `key` and `isRequired` is false.
  result = true

  if data.hasKey(key):
    if not isArrayOf(data[key], key, path, call, isRequired):
      result = false
  elif isRequired:
    result.setFalseAndPrint("Missing key: " & q(key), path)

proc checkBoolean*(data: JsonNode; key, path: string; isRequired = true): bool =
  result = true
  if data.hasKey(key):
    case data[key].kind
    of JBool:
      return true
    of JNull:
      if isRequired:
        result.setFalseAndPrint("Value is `null`, but must be a bool: " &
                                q(key), path)
    else:
      result.setFalseAndPrint("Not a bool: " & q(key) & ": " & $data[key], path)
  elif isRequired:
    result.setFalseAndPrint("Missing key: " & q(key), path)

proc checkInteger*(data: JsonNode; key, path: string; isRequired = true;
                   allowed: Slice): bool =
  result = true
  if data.hasKey(key):
    case data[key].kind
    of JInt:
      let num = data[key].getInt()
      if num notin allowed:
        let msgStart = "The value of `" & key & "` is `" & $num &
                       "`, but it must be "
        let msgEnd =
          if allowed.len == 1:
            "`" & $allowed.a & "`"
          else:
            "between " & $allowed.a & " and " & $allowed.b & " (inclusive)"
        result.setFalseAndPrint(msgStart & msgEnd, path)
    of JNull:
      if isRequired:
        result.setFalseAndPrint("Value is `null`, but must be an integer: " &
                                q(key), path)
    else:
      result.setFalseAndPrint("Not an integer: " & q(key) & ": " & $data[key], path)
  elif isRequired:
    result.setFalseAndPrint("Missing key: " & q(key), path)

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
