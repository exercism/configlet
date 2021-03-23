import std/[json, os, strutils]
import ".."/helpers
import "."/validators

proc isUrlLike(s: string): bool =
  ## Returns true if `s` starts with `https://`, `http://` or `www`.
  # We probably only need simplistic URL checking, and we want to avoid using
  # Nim's stdlib regular expressions in order to avoid a dependency on PCRE.
  s.startsWith("https://") or s.startsWith("http://") or s.startsWith("www")

proc isValidLinkObject(data: JsonNode, context: string, path: string): bool =
  ## Returns true if `data` is a `JObject` that satisfies all of the below:
  ## - has a `url` key, with a value that is a URL-like string.
  ## - has a `description` key, with a value that is a non-empty, non-blank
  ##   string.
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

proc isEveryConceptLinksFileValid*(trackDir: string): bool =
  let conceptsDir = trackDir / "concepts"
  result = true

  if dirExists(conceptsDir):
    for subdir in getSortedSubdirs(conceptsDir):
      let linksPath = subdir / "links.json"
      let j = parseJsonFile(linksPath, result, allowEmptyArray = true)
      if j != nil:
        if not isValidLinksFile(j, linksPath):
          result = false

proc conceptDocsExist*(trackDir: string): bool =
  ## Returns true if every subdirectory in `trackDir/concepts` has the required
  ## Markdown files.
  const
    requiredConceptDocs = [
      "about.md",
      "introduction.md",
    ]

  let conceptsDir = trackDir / "concepts"
  result = subdirsContain(conceptsDir, requiredConceptDocs)
