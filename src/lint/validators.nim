import std/json
import ".."/helpers

template checkObject*(key: string, isRequired = true) =
  if key.len == 0:
    if data.kind != JObject:
      writeError("JSON root is not an object", path)
      return false
  elif data.hasKey(key):
    if data[key].kind != JObject:
      writeError("Not an object: " & key, path)
      return false
  elif isRequired:
    writeError("Missing key: " & key, path)
    return false

template checkString*(key: string, isRequired = true) =
  if data.hasKey(key):
    if data[key].kind == JString:
      if data[key].getStr().len == 0:
        writeError("String is zero-length: " & key, path)
    else:
      writeError("Not a string: `" & key & ": " & $data[key] & "`", path)
  elif isRequired:
    writeError("Missing key: " & key, path)

proc format(context, key: string): string =
  if context.len > 0:
    context & "." & key
  else:
    key

template checkArrayOfStrings*(context, key: string; isRequired = true) =
  var d = if context.len == 0: data else: data[context]
  if d.hasKey(key):
    if d[key].kind == JArray:
      if d[key].len == 0:
        writeError("Array is empty: " & key, path)
      else:
        for item in d[key]:
          if item.kind != JString:
            result = false
            writeError("Array contains non-string: " & format(context, key) & ": " & $item, path)
            # break
          elif item.getStr().len == 0:
            writeError("Array contains zero-length string: " & format(context, key), path)
    else:
      writeError("Not an array: " & key, path)
  elif isRequired:
    writeError("Missing key: " & format(context, key), path)

template checkArrayOf*(key: string,
                       call: proc(d: JsonNode; key, path: string): bool,
                       isRequired = true) =
  if data.hasKey(key):
    if data[key].kind == JArray:
      if data[key].len == 0:
        writeError("Array is empty: " & key, path)
      else:
        for item in data[key]:
          if not call(item, key, path):
            result = false
            # writeError("Item in array fails check: " & $item, path)
            # break
    else:
      writeError("Not an array: " & key, path)
  elif isRequired:
    writeError("Missing key: " & key, path)
