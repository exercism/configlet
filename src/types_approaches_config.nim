import std/options
import "."/helpers

type
  ApproachesConfigKey* = enum
    ackIntroduction = "introduction"
    ackApproaches = "approaches"

  ApproachKey* = enum
    akUuid = "uuid"
    akSlug = "slug"
    akTitle = "title"
    akBlurb = "blurb"
    akAuthors = "authors"
    akContributors = "contributors"
    akTags = "tags"

  ApproachIntroductionKey* = enum
    aiAuthors = "authors"
    aiContributors = "contributors"

  ApproachesIntroductionConfig* = object
    authors*: seq[string]
    contributors*: seq[string]

  ApproachConfigTags* = object
    all*: seq[string]
    `any`*: seq[string]
    `not`*: seq[string]

  ApproachConfig* = object
    uuid*: string
    slug*: string
    title*: string
    blurb*: string
    authors*: seq[string]
    contributors*: seq[string]
    tags*: Option[ApproachConfigTags]

  ApproachesConfig* = object
    introduction*: ApproachesIntroductionConfig
    approaches*: seq[ApproachConfig]

proc init*(T: typedesc[ApproachesConfig]; approachesConfigFilePath: string): T =
  ## Deserializes contents of `approachesConfigFilePath` using `jsony` to
  ## an `ApproachesConfig` object.
  parseFile(approachesConfigFilePath, ApproachesConfig)
