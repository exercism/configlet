import std/[json, options, os, strformat, strutils]
import ".."/[helpers, sync/sync_common, types_approaches_config, types_articles_config]
import "."/validators

type
  DocumentKind = enum
    dkApproaches = ".approaches"
    dkArticles = ".articles"

proc setFalseIfFileMissingOrEmpty(b: var bool, path: Path, msgMissing: string) =
  if fileExists(path):
    if path.readFile().len == 0:
      let msg = &"The below file is empty"
      b.setFalseAndPrint(msg, path)
  else:
    b.setFalseAndPrint(msgMissing, path)

proc hasValidIntroduction(data: JsonNode, path: Path): bool =
  const k = "introduction"
  if hasObject(data, k, path, isRequired = false):
    let d = data[k]
    let checks = [
      hasArrayOfStrings(d, "authors", path, k, uniqueValues = true),
      hasArrayOfStrings(d, "contributors", path, k, isRequired = false),
    ]
    result = allTrue(checks)
  if data.kind == JObject and data.hasKey(k):
    let introductionPath = Path(path.parentDir() / "introduction.md")
    let msg = &"The config.json '{k}' object is present, but there is no " &
              "corresponding introduction file at the below location"
    result.setFalseIfFileMissingOrEmpty(introductionPath, msg)

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
    if result:
      let slug = data["slug"].getStr()
      let dkDir = path.parentDir()
      let slugDir = Path(dkDir / slug)
      if not dirExists(slugDir):
        let msg = &"A config.json '{context}.slug' value is '{slug}', but " &
                  "there is no corresponding directory at the below location"
        result.setFalseAndPrint(msg, slugDir)
      block:
        let contentPath = slugDir / "content.md"
        let msg = &"A config.json '{context}.slug' value is '{slug}', but " &
                  "there is no corresponding content file at the below location"
        result.setFalseIfFileMissingOrEmpty(contentPath, msg)
      block:
        let ext = if dkDir.endsWith($dkApproaches): "txt" else: "md"
        let snippetPath = slugDir / &"snippet.{ext}"
        let msg = &"A config.json '{context}.slug' value is '{slug}', but " &
                  "there is no corresponding snippet file at the below location"
        result.setFalseIfFileMissingOrEmpty(snippetPath, msg)

proc getSlugs(data: JsonNode, k: string): seq[string] =
  result = @[]
  if data.kind == JObject and data.hasKey(k):
    if data[k].kind == JArray:
      let elems = data[k].getElems()
      for e in elems:
        if e.kind == JObject and e.hasKey("slug") and e["slug"].kind == JString:
          result.add e["slug"].getStr()

proc isValidConfig(data: JsonNode, path: Path, dk: DocumentKind): bool =
  if isObject(data, jsonRoot, path):
    let k = dk.`$`[1..^1] # Remove dot.
    let checks = [
      if dk == dkApproaches: hasValidIntroduction(data, path) else: true,
      hasArrayOf(data, k, path, isValidApproachOrArticle, isRequired = false),
    ]
    result = allTrue(checks)
    if result:
      let slugsInConfig = getSlugs(data, k)
      for dir in getSortedSubdirs(path.parentDir().Path, relative = true):
        if dir.string notin slugsInConfig:
          let msg = &"There is no '{k}.slug' key with the value '{dir}', " &
                    &"but a sibling directory exists with that name"
          result.setFalseAndPrint(msg, path)

proc isConfigMissingOrValid(dir: Path, dk: DocumentKind): bool =
  result = true
  let dkPath = dir / $dk
  let configPath = dkPath / "config.json"
  if fileExists(configPath):
    let j = parseJsonFile(configPath, result)
    if j != nil:
      if not isValidConfig(j, configPath, dk):
        result = false
  else:
    if dk == dkApproaches and fileExists(dkPath / "introduction.md"):
      let msg = &"The below directory has an 'introduction.md' file, but " &
                "does not contain a 'config.json' file"
      result.setFalseAndPrint(msg, dkPath)
    for dir in getSortedSubdirs(dkPath, relative = true):
      let msg = &"The below directory has a '{dir}' subdirectory, but does " &
                "not contain a 'config.json' file"
      result.setFalseAndPrint(msg, dkPath)

func countLinesWithoutCodeFence(s: string, dk: DocumentKind): int =
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

proc isEverySnippetValid(exerciseDir: Path, dk: DocumentKind): bool =
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
      for dk in DocumentKind:
        if not isConfigMissingOrValid(exerciseDir, dk):
          result = false
        if not isEverySnippetValid(exerciseDir, dk):
          result = false
