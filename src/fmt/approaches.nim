import std/[json, options, strformat]
import ".."/[helpers, sync/sync_common, types_approaches_config]

func approachesConfigKeyOrderForFmt(e: ApproachesConfig): seq[ApproachesConfigKey] =
  result = @[]
  if e.introduction.authors.len > 0:
    result.add ackIntroduction
  if e.approaches.len > 0:
    result.add ackApproaches

func addApproachesIntroduction(result: var string;
                               val: ApproachesIntroductionConfig;
                               indentLevel = 1) =
  ## Appends the pretty-printed JSON for an `introduction` key with value `val` to
  ## `result`.
  result.addNewlineAndIndent(indentLevel)
  escapeJson("introduction", result)
  result.add ": {"
  result.addArray("authors", val.authors, indentLevel + 1)
  if val.contributors.len > 0:
    result.addArray("contributors", val.contributors, indentLevel + 1)
  result.removeComma()
  result.addNewlineAndIndent(indentLevel)
  result.add "},"

func addApproachTags(result: var string; val: ApproachConfigTags; indentLevel = 2) =
  result.addNewlineAndIndent(indentLevel)
  escapeJson("tags", result)
  result.add ": {"
  if val.all.len > 0:
    result.addArray("all", val.all, indentLevel + 1)
  if val.`any`.len > 0:
    result.addArray("any", val.`any`, indentLevel + 1)
  if val.`not`.len > 0:
    result.addArray("not", val.`not`, indentLevel + 1)
  result.removeComma()
  result.addNewlineAndIndent(indentLevel)
  result.add "},"

func addApproach(result: var string; val: ApproachConfig; indentLevel = 1) =
  ## Appends the pretty-printed JSON for an `approach` object with value `val` to
  ## `result`.
  result.addNewlineAndIndent(indentLevel)
  result.add "{"
  result.addString("uuid", val.uuid, indentLevel + 1)
  result.addString("slug", val.slug, indentLevel + 1)
  result.addString("title", val.title, indentLevel + 1)
  result.addString("blurb", val.blurb, indentLevel + 1)
  result.addArray("authors", val.authors, indentLevel + 1)
  if val.contributors.len > 0:
    result.addArray("contributors", val.contributors, indentLevel + 1)
  if val.tags.isSome():
    let tags = val.tags.get()
    if tags.all.len + tags.`any`.len + tags.`not`.len > 0:
      result.addApproachTags(tags, indentLevel + 1)
  result.removeComma()
  result.addNewlineAndIndent(indentLevel)
  result.add "},"

func addApproaches(result: var string;
                   val: seq[ApproachConfig];
                   indentLevel = 1) =
  ## Appends the pretty-printed JSON for an `approaches` key with value `val` to
  ## `result`.
  result.addNewlineAndIndent(indentLevel)
  escapeJson("approaches", result)
  result.add ": ["
  for approach in val:
    result.addApproach(approach, indentLevel + 1)
  result.removeComma()
  result.addNewlineAndIndent(indentLevel)
  result.add "]"

func prettyApproachesConfig*(e: ApproachesConfig): string =
  ## Serializes `e` as pretty-printed JSON, using the canonical key order.
  let keys = approachesConfigKeyOrderForFmt(e)

  result = newStringOfCap(1000)
  result.add '{'
  for key in keys:
    case key
    of ackIntroduction:
      if e.introduction.authors.len > 0 or e.introduction.contributors.len > 0:
        result.addApproachesIntroduction(e.introduction)
    of ackApproaches:
      if e.approaches.len > 0:
        result.addApproaches(e.approaches)
  result.removeComma()
  result.add "\n}\n"

proc formatApproachesConfigFile*(configPath: string): string =
  ## Parses the `.approaches/config.json` file at `configPath` and
  ## returns it in the canonical form.
  let approachesConfig = ApproachesConfig.init(configPath)
  prettyApproachesConfig(approachesConfig)
