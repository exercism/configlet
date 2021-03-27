import std/[json, os]
import ".."/helpers
import "."/validators

proc isValidLinkObject(data: JsonNode, context: string, path: string): bool =
  ## Returns true if `data` is a `JObject` that satisfies all of the below:
  ## - has a `url` key, with a value that is a URL-like string.
  ## - has a `description` key, with a value that is a non-empty, non-blank
  ##   string.
  ## - if it has a `icon_url` key, the corresponding value is a URL-like string.
  if isObject(data, context, path):
    result = true

    if not checkString(data, "url", path, checkIsUrlLike = true):
      result = false
    if not checkString(data, "description", path):
      result = false
    if not checkString(data, "icon_url", path, isRequired = false,
                       checkIsUrlLike = true):
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
