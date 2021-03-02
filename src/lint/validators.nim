import std/[json, strutils]
import ".."/helpers
export strutils.strip

proc q(s: string): string =
  "'" & s & "'"

proc isObject*(data: JsonNode; context, path: string): bool =
  result = true
  if data.kind != JObject:
    result.setFalseAndPrint("Not an object: " & q(context), path)

proc hasObject*(data: JsonNode; key, path: string,
               isRequired = true): bool =
  result = true
  if data.hasKey(key):
    if data[key].kind != JObject:
      result.setFalseAndPrint("Not an object: " & q(key), path)
  elif isRequired:
    result.setFalseAndPrint("Missing key: " & q(key), path)

proc checkString*(data: JsonNode; key, path: string, isRequired = true): bool =
  result = true
  if data.hasKey(key):
    if data[key].kind == JString:
      let s = data[key].getStr()
      if s.len == 0:
        result.setFalseAndPrint("String is zero-length: " & q(key), path)
      elif s.strip().len == 0:
        result.setFalseAndPrint("String is whitespace-only: " & q(key), path)
    else:
      result.setFalseAndPrint("Not a string: " & q(key) & ": " & $data[key], path)
  elif isRequired:
    result.setFalseAndPrint("Missing key: " & q(key), path)

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
          result.setFalseAndPrint("Array is empty: " & format(context, key), path)
      else:
        for item in d[key]:
          if item.kind == JString:
            let s = item.getStr()
            if s.len == 0:
              result.setFalseAndPrint("Array contains zero-length string: " &
                                      format(context, key), path)
            elif s.strip().len == 0:
              result.setFalseAndPrint("Array contains whitespace-only string: " &
                                      q(key), path)
          else:
            result.setFalseAndPrint("Array contains non-string: " &
                                    format(context, key) & ": " & $item, path)
    else:
      result.setFalseAndPrint("Not an array: " & format(context, key), path)
  elif isRequired:
    result.setFalseAndPrint("Missing key: " & format(context, key), path)

proc checkArrayOf*(data: JsonNode, key, path: string,
                   call: proc(d: JsonNode; key, path: string): bool,
                   isRequired = true): bool =
  result = true
  if data.hasKey(key):
    if data[key].kind == JArray:
      if data[key].len == 0:
        if isRequired:
          result.setFalseAndPrint("Array is empty: " & q(key), path)
      else:
        for item in data[key]:
          if not call(item, key, path):
            result = false
    else:
      result.setFalseAndPrint("Not an array: " & q(key), path)
  elif isRequired:
    result.setFalseAndPrint("Missing key: " & q(key), path)

proc checkBoolean*(data: JsonNode; key, path: string, isRequired = true): bool =
  result = true
  if data.hasKey(key):
    if data[key].kind != JBool:
      result.setFalseAndPrint("Not a bool: " & q(key) & ": " & $data[key], path)
  elif isRequired:
    result.setFalseAndPrint("Missing key: " & q(key), path)

proc checkInteger*(data: JsonNode; key, path: string, isRequired = true): bool =
  result = true
  if data.hasKey(key):
    if data[key].kind != JInt:
      result.setFalseAndPrint("Not an integer: " & q(key) & ": " & $data[key], path)
  elif isRequired:
    result.setFalseAndPrint("Missing key: " & q(key), path)
