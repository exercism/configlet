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

proc createApproach*(approachSlug: Slug, exerciseDir: string) =
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

  config.approaches.add ApproachConfig(
    uuid: $genUUID(),
    slug: $approachSlug,
    title: kebabToTitleCase(approachSlug),
    blurb: "",
    authors: newSeq[string]()
  )

  writeFile(configPath, config.toJson())

# hasString(data, "uuid", path, context, checkIsUuid = true),
#       hasString(data, "slug", path, context, checkIsKebab = true),
#       hasString(data, "title", path, context, maxLen = 255),
#       hasString(data, "blurb", path, context, maxLen = 280),
#       hasArrayOfStrings(data, "authors", path, context, uniqueValues = true),
#   "{"
#   writeFile()

  #   let j = parseJsonFile(configPath, result)
  #   if j != nil:
  #     if not isValidConfig(j, configPath, dk):
  #       result = false
  # else:
  #   if dk == dkApproaches and fileExists(dkPath / "introduction.md"):
  #     let msg = &"The below directory has an 'introduction.md' file, but " &
  #               "does not contain a 'config.json' file"
  #     result.setFalseAndPrint(msg, dkPath)
  #   for dir in getSortedSubdirs(dkPath, relative = true):
  #     let msg = &"The below directory has a '{dir}' subdirectory, but does " &
  #               "not contain a 'config.json' file"
  #     result.setFalseAndPrint(msg, dkPath)

