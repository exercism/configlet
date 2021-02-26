import std/[json, os, strutils]
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

proc checkString*(data: JsonNode; key, path: string; isRequired = true): bool =
  result = true
  if data.hasKey(key):
    if data[key].kind == JString:
      let s = data[key].getStr()
      if s.len > 0:
        if s.strip().len == 0:
          result.setFalseAndPrint("String is whitespace-only: " & q(key), path)
      else:
        result.setFalseAndPrint("String is zero-length: " & q(key), path)
    elif data[key].kind != JNull or isRequired:
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

  if data.kind == JArray:
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
  elif data.kind != JNull or isRequired:
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

  if data.kind == JArray:
    if data.len > 0:
      for item in data:
        if not call(item, context, path):
          result = false
    elif isRequired:
      result.setFalseAndPrint("Array is empty: " & q(context), path)
  elif data.kind != JNull or isRequired:
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
    if data[key].kind == JBool:
      return
    elif data[key].kind != JNull or isRequired:
      result.setFalseAndPrint("Not a bool: " & q(key) & ": " & $data[key], path)
  elif isRequired:
    result.setFalseAndPrint("Missing key: " & q(key), path)

proc checkInteger*(data: JsonNode; key, path: string; isRequired = true): bool =
  result = true
  if data.hasKey(key):
    if data[key].kind == JInt:
      return
    elif data[key].kind != JNull or isRequired:
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
