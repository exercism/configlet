import std/json
import ".."/helpers
import "."/validators

proc isValidLinkObject(data: JsonNode, context: string, path: Path): bool =
  ## Returns true if `data` is a `JObject` that satisfies all of the below:
  ## - has a `url` key, with a value that is a URL-like string.
  ## - has a `description` key, with a value that is a non-empty, non-blank
  ##   string.
  ## - if it has a `icon_url` key, the corresponding value is a URL-like string.
  if isObject(data, context, path):
    let checks = [
      hasString(data, "url", path, context, checkIsUrlLike = true),
      hasString(data, "description", path, context),
      hasString(data, "icon_url", path, context, isRequired = false,
                checkIsUrlLike = true),
    ]
    result = allTrue(checks)
  else:
    result.setFalseAndPrint("At least one element of the top-level array is " &
                            "not an object: " & $data, path)

proc isValidLinksFile(data: JsonNode, path: Path): bool =
  result = isArrayOf(data, jsonRoot, path, isValidLinkObject,
                     isRequired = false, allowedLength = 0..int.high)

proc isEveryConceptLinksFileValid*(trackDir: Path): bool =
  let conceptsDir = trackDir / "concepts"
  result = true

  if dirExists(conceptsDir):
    for subdir in getSortedSubdirs(conceptsDir):
      let linksPath = subdir / "links.json"
      let j = parseJsonFile(linksPath, result, allowEmptyArray = true)
      if j != nil:
        if not isValidLinksFile(j, linksPath):
          result = false

proc isValidConceptConfig(data: JsonNode, path: Path): bool =
  if isObject(data, jsonRoot, path):
    let checks = [
      hasString(data, "blurb", path, maxLen = 350),
      hasArrayOfStrings(data, "authors", path, uniqueValues = true),
      hasArrayOfStrings(data, "contributors", path, isRequired = false,
                        uniqueValues = true),
    ]
    result = allTrue(checks)

proc isEveryConceptConfigValid*(trackDir: Path): bool =
  let conceptsDir = trackDir / "concepts"
  result = true

  if dirExists(conceptsDir):
    for conceptDir in getSortedSubdirs(conceptsDir):
      let configPath = conceptDir / ".meta" / "config.json"
      let j = parseJsonFile(configPath, result)
      if j != nil:
        if not isValidConceptConfig(j, configPath):
          result = false

proc conceptDocsExist*(trackDir: Path): bool =
  ## Returns true if every subdirectory in `trackDir/concepts` has the required
  ## Markdown files.
  const
    requiredConceptDocs = [
      "about.md",
      "introduction.md",
    ]

  let conceptsDir = trackDir / "concepts"
  result = subdirsContain(conceptsDir, requiredConceptDocs)
