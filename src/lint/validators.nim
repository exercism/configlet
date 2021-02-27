import std/[json, strutils]
import ".."/helpers
export strutils.strip

proc q(s: string): string =
  "'" & s & "'"

proc isObject*(data: JsonNode; context, path: string): bool =
  result = true
  if data.kind != JObject:
    writeError("Not an object: " & q(context), path)
    result = false

proc hasObject*(data: JsonNode; key, path: string,
               isRequired = true): bool =
  result = true
  if data.hasKey(key):
    if data[key].kind != JObject:
      writeError("Not an object: " & q(key), path)
      result = false
  elif isRequired:
    writeError("Missing key: " & q(key), path)
    result = false

proc checkString*(data: JsonNode; key, path: string, isRequired = true): bool =
  result = true
  if data.hasKey(key):
    if data[key].kind == JString:
      let s = data[key].getStr()
      if s.len == 0:
        writeError("String is zero-length: " & q(key), path)
        result = false
      elif s.strip().len == 0:
        writeError("String is whitespace-only: " & q(key), path)
        result = false
    else:
      writeError("Not a string: " & q(key) & ": " & $data[key], path)
      result = false
  elif isRequired:
    writeError("Missing key: " & q(key), path)
    result = false

proc format(context, key: string): string =
  if context.len > 0:
    q(context & "." & key)
  else:
    q(key)

proc checkArrayOfStrings*(data: JsonNode, context, key, path: string; isRequired = true): bool =
  result = true
  var d = if context.len == 0: data else: data[context]
  if d.hasKey(key):
    if d[key].kind == JArray:
      if d[key].len == 0:
        if isRequired:
          writeError("Array is empty: " & format(context, key), path)
          result = false
      else:
        for item in d[key]:
          if item.kind == JString:
            let s = item.getStr()
            if s.len == 0:
              writeError("Array contains zero-length string: " & format(context, key), path)
              result = false
            elif s.strip().len == 0:
              writeError("Array contains whitespace-only string: " & q(key), path)
              result = false
          else:
            writeError("Array contains non-string: " & format(context, key) & ": " & $item, path)
            result = false
    else:
      writeError("Not an array: " & format(context, key), path)
      result = false
  elif isRequired:
    writeError("Missing key: " & format(context, key), path)
    result = false

proc checkArrayOf*(data: JsonNode, key, path: string,
                   call: proc(d: JsonNode; key, path: string): bool,
                   isRequired = true): bool =
  result = true
  if data.hasKey(key):
    if data[key].kind == JArray:
      if data[key].len == 0:
        if isRequired:
          writeError("Array is empty: " & q(key), path)
          result = false
      else:
        for item in data[key]:
          if not call(item, key, path):
            result = false
    else:
      writeError("Not an array: " & q(key), path)
      result = false
  elif isRequired:
    writeError("Missing key: " & q(key), path)
    result = false

proc checkBoolean*(data: JsonNode; key, path: string, isRequired = true): bool =
  result = true
  if data.hasKey(key):
    if data[key].kind != JBool:
      writeError("Not a bool: " & q(key) & ": " & $data[key], path)
      result = false
  elif isRequired:
    writeError("Missing key: " & q(key), path)
    result = false

proc checkInteger*(data: JsonNode; key, path: string, isRequired = true): bool =
  result = true
  if data.hasKey(key):
    if data[key].kind != JInt:
      writeError("Not an integer: " & q(key) & ": " & $data[key], path)
      result = false
  elif isRequired:
    writeError("Missing key: " & q(key), path)
    result = false
