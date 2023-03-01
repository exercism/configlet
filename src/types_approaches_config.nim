import std/options
import pkg/jsony
import "."/[cli, helpers]

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

  ApproachIntroductionKey* = enum
    aiAuthors = "authors"
    aiContributors = "contributors"

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

proc init*(T: typedesc[ApproachesConfig]; approachesConfigContents: string): T =
  ## Deserializes `approachesConfigContents` using `jsony` to a `ApproachesConfig` object.
  try:
    result = fromJson(approachesConfigContents, ApproachesConfig)
  except jsony.JsonError:
    let msg = tidyJsonyErrorMsg(approachesConfigContents)
    showError(msg)
