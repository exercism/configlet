import std/[json, strformat, strutils]
import ".."/helpers
import "."/validators

type
  DirKind = enum
    dkApproaches = ".approaches"
    dkArticles = ".articles"

proc hasValidIntroduction(data: JsonNode, path: Path): bool =
  const k = "introduction"
  if hasObject(data, k, path, isRequired = false):
    let d = data[k]
    let checks = [
      hasArrayOfStrings(d, "authors", path, k, uniqueValues = true),
      hasArrayOfStrings(d, "contributors", path, k, isRequired = false),
    ]
    result = allTrue(checks)

proc isValidApproachOrArticle(data: JsonNode, context: string,
                              path: Path): bool =
  if isObject(data, context, path):
    let checks = [
      hasString(data, "uuid", path, context, checkIsUuid = true),
      hasString(data, "slug", path, context, checkIsKebab = true),
      hasString(data, "title", path, context, maxLen = 255),
      hasString(data, "blurb", path, context, maxLen = 280),
      hasArrayOfStrings(data, "authors", path, context, uniqueValues = true),
      hasArrayOfStrings(data, "contributors", path, context,
                        isRequired = false),
    ]
    result = allTrue(checks)

proc isValidConfig(data: JsonNode, path: Path, dk: DirKind): bool =
  if isObject(data, jsonRoot, path):
    let k = dk.`$`[1..^1] # Remove dot.
    let checks = [
      if dk == dkApproaches: hasValidIntroduction(data, path) else: true,
      hasArrayOf(data, k, path, isValidApproachOrArticle, isRequired = false),
    ]
    result = allTrue(checks)

proc isConfigMissingOrValid(dir: Path, dk: DirKind): bool =
  result = true
  let configPath = dir / $dk / "config.json"
  if fileExists(configPath):
    let j = parseJsonFile(configPath, result)
    if j != nil:
      if not isValidConfig(j, configPath, dk):
        result = false

func countLinesWithoutCodeFence(s: string, dk: DirKind): int =
  ## Returns the number of lines in `s`, but:
  ##
  ## - excluding lines that open or close a Markdown code fence.
  ## - including a final line that does not end in a newline character.
  result = 0
  if s.len > 0:
    for line in s.splitLines():
      if not (line.startsWith("```") and dk == dkArticles):
        inc result
    if s[^1] in ['\n', '\l']:
      dec result

proc isEverySnippetValid(exerciseDir: Path, dk: DirKind): bool =
  result = true
  for dir in getSortedSubdirs(exerciseDir / $dk):
    let snippetPath = block:
      let ext = if dk == dkApproaches: "txt" else: "md"
      dir / &"snippet.{ext}"
    if fileExists(snippetPath):
      let contents = readFile(snippetPath)
      const maxLines = 8
      let numLines = countLinesWithoutCodeFence(contents, dk)
      if numLines > maxLines:
        let msg = &"The file is {numLines} lines long, but it must be at " &
                  &"most {maxLines} lines long"
        result.setFalseAndPrint(msg, snippetPath)

proc isEveryApproachAndArticleValid*(trackDir: Path): bool =
  result = true
  for exerciseKind in ["concept", "practice"]:
    for exerciseDir in getSortedSubdirs(trackDir / "exercises" / exerciseKind):
      for dk in DirKind:
        if not isConfigMissingOrValid(exerciseDir, dk):
          result = false
        if not isEverySnippetValid(exerciseDir, dk):
          result = false
