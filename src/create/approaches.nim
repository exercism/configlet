import std/[options, os, strformat, strutils]
import pkg/[jsony, uuids]
import ".."/[cli, logger, sync/sync_common, sync/sync_filepaths, sync/sync, types_track_config]

type
  ApproachesIntroductionConfig* = object
    authors*: seq[string]
    contributors*: Option[seq[string]]

  ApproachConfig* = object
    uuid*: string
    slug*: string
    title*: string
    blurb*: string
    authors*: seq[string]
    contributors*: Option[seq[string]]

  ApproachesConfig* = object
    introduction*: Option[ApproachesIntroductionConfig]
    approaches*: seq[ApproachConfig]

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

proc createApproach*(approachSlug: Slug, exerciseSlug: Slug, exerciseDir: string) =
  let approachesDir = exerciseDir / ".approaches"
  let configPath = approachesDir / "config.json"

  if not dirExists(approachesDir):
    createDir(approachesDir)

  var config = 
    if not fileExists(configPath):
      ApproachesConfig(
        introduction: none[ApproachesIntroductionConfig](),
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
      uuid: $genUUID(),
      slug: $approachSlug,
      title: title,
      blurb: "",
      authors: newSeq[string]()
    )

    writeFile(configPath, config.toJson())

  let approachDir = approachesDir / $approachSlug
  if not dirExists(approachDir):
    createDir(approachDir)

  let contentPath = approachDir / "content.md"
  let snippetPath = approachDir / "snippet.txt"

  if not fileExists(contentPath):
    writeFile(contentPath, &"# {title}\n\n")

  if not fileExists(snippetPath):
    writeFile(snippetPath, "")
