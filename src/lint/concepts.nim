import std/[json, os, strutils]
import ".."/helpers
import "."/validators

proc isUrlLike(s: string): bool =
  ## Returns true if `s` starts with `http://`, `https://` or `www`.
  # For now, this is deliberately simplistic. We probably don't need
  # sophisticated URL checking, and we don't want to use Nim's stdlib regular
  # expressions because that would add a dependency on PCRE.
  if s.startsWith("http"):
    if s.continuesWith("://", 4) or s.continuesWith("s://", 4):
      result = true
  elif s.startsWith("www"):
    result = true

proc isValidLinkObject(data: JsonNode, context: string, path: string): bool =
  ## Returns true if `data` is a `JObject` that satisfies all of the below:
  ## - has a `url` key, with a value that is a URL-like string.
  ## - has a `description` key, with a value that is a non-empty, non-blank string.
  ## - if it has a `icon_url` key, the corresponding value is a URL-like string.
  if isObject(data, context, path):
    result = true

    if checkString(data, "url", path):
      let s = data["url"].getStr()
      if not isUrlLike(s):
        result.setFalseAndPrint("Not a valid URL: " & s, path)
    else:
      result = false

    if not checkString(data, "description", path):
      result = false

    if data.hasKey("icon_url"):
      if checkString(data, "icon_url", path, isRequired = false):
        let s = data["icon_url"].getStr()
        if not isUrlLike(s):
          result.setFalseAndPrint("Not a valid URL: " & s, path)
      else:
        result = false
  else:
    result.setFalseAndPrint("At least one element of the top-level array is " &
                            "not an object: " & $data[context], path)

proc isValidLinksFile(data: JsonNode, path: string): bool =
  result = isArrayOf(data, "", path, isValidLinkObject, isRequired = false)

proc isNonBlank(path: string): bool =
  ## Returns true if `path` points to a file that has at least one
  ## non-whitespace character.
  let contents = readFile(path)
  for c in contents:
    if c notin Whitespace:
      return true

proc isEveryConceptLinksFileValid*(trackDir: string): bool =
  let conceptsDir = trackDir / "concepts"
  result = true

  if dirExists(conceptsDir):
    for subdir in getSortedSubdirs(conceptsDir):
      let linksPath = subdir / "links.json"
      if fileExists(linksPath):
        if isNonBlank(linksPath):
          let j =
            try:
              parseFile(linksPath) # Shows the filename in the exception message.
            except CatchableError:
              result.setFalseAndPrint("JSON parsing error", getCurrentExceptionMsg())
              continue
          if not isValidLinksFile(j, linksPath):
            result = false
        else:
          result.setFalseAndPrint("File is empty, but must contain at least " &
                                  "the empty array, `[]`", linksPath)
      else:
        result.setFalseAndPrint("Missing file", linksPath)

proc conceptFilesExist*(trackDir: string): bool =
  ## Returns true if every subdirectory in `trackDir/concepts` has the required
  ## files.
  const
    requiredConceptFiles = [
      "about.md",
      "introduction.md",
      "links.json",
    ]

  let conceptsDir = trackDir / "concepts"
  result = subdirsContain(conceptsDir, requiredConceptFiles)
