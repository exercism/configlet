import std/[os, strformat, strutils]
import ".."/[fmt/approaches, helpers, sync/sync_common, types_track_config,
             types_approaches_config, uuid/uuid]

func kebabToTitleCase(slug: Slug): string =
  result = newStringOfCap(slug.len)
  var capitalizeNext = true
  for c in slug.string:
    if c == '-':
      result.add ' '
      capitalizeNext = true
    else:
      result.add(if capitalizeNext: toUpperAscii(c) else: c)
      capitalizeNext = false

proc createApproach*(approachSlug: Slug, exerciseSlug: Slug,
    exerciseDir: string) =
  let approachesDir = exerciseDir / ".approaches"
  let configPath = approachesDir / "config.json"

  if not dirExists(approachesDir):
    createDir(approachesDir)

  var config =
    if not fileExists(configPath):
      ApproachesConfig(
        introduction: ApproachesIntroductionConfig(
          authors: newSeq[string](),
          contributors: newSeq[string]()
        ),
        approaches: newSeq[ApproachConfig]()
      )
    else:
      parseFile(configPath, ApproachesConfig)

  var approachExists = false

  for approach in config.approaches:
    if $approachSlug == approach.slug:
      approachExists = true
      break

  let title = kebabToTitleCase(approachSlug)

  if not approachExists:
    config.approaches.add ApproachConfig(
      uuid: $genUuid(),
      slug: $approachSlug,
      title: title,
      blurb: "",
      authors: newSeq[string]()
    )

    let formattedConfig = prettyApproachesConfig(config)
    writeFile(configPath, formattedConfig)

  let approachDir = approachesDir / $approachSlug
  if not dirExists(approachDir):
    createDir(approachDir)

  let contentPath = approachDir / "content.md"
  let snippetPath = approachDir / "snippet.txt"

  if not fileExists(contentPath):
    writeFile(contentPath, &"# {title}\n\n")

  if not fileExists(snippetPath):
    writeFile(snippetPath, "")

  echo &"Created approach '{approachSlug}' for the exercise '{exerciseSlug}'."
