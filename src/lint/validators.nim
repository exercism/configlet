import std/[json, terminal]
import ".."/helpers

proc q(s: string): string =
  "'" & s & "'"

proc isObject*(data: JsonNode, key: string, path: string,
               isRequired = true): bool =
  result = true
  if key.len == 0:
    if data.kind != JObject:
      writeError("JSON root is not an object", path)
  elif data.hasKey(key):
    if data[key].kind != JObject:
      writeError("Not an object: " & q(key), path)
  elif isRequired:
    writeError("Missing key: " & q(key), path)

template checkString*(key: string, isRequired = true) =
  if data.hasKey(key):
    if data[key].kind == JString:
      if data[key].getStr().len == 0:
        writeError("String is zero-length: " & q(key), path)
    else:
      writeError("Not a string: " & q(key) & ": " & $data[key], path)
  elif isRequired:
    writeError("Missing key: " & q(key), path)

proc format(context, key: string): string =
  if context.len > 0:
    q(context & "." & key)
  else:
    q(key)

template checkArrayOfStrings*(context, key: string; isRequired = true) =
  var d = if context.len == 0: data else: data[context]
  if d.hasKey(key):
    if d[key].kind == JArray:
      if d[key].len == 0:
        writeError("Array is empty: " & format(context, key), path)
      else:
        for item in d[key]:
          if item.kind != JString:
            writeError("Array contains non-string: " & format(context, key) & ": " & $item, path)
          elif item.getStr().len == 0:
            writeError("Array contains zero-length string: " & format(context, key), path)
    else:
      writeError("Not an array: " & format(context, key), path)
  elif isRequired:
    writeError("Missing key: " & format(context, key), path)

template checkArrayOf*(key: string,
                       call: proc(d: JsonNode; key, path: string): bool,
                       isRequired = true) =
  if data.hasKey(key):
    if data[key].kind == JArray:
      if data[key].len == 0:
        writeError("Array is empty: " & q(key), path)
      else:
        for item in data[key]:
          if not call(item, key, path):
            result = false
    else:
      writeError("Not an array: " & q(key), path)
  elif isRequired:
    writeError("Missing key: " & q(key), path)
