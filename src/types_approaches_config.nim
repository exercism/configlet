import std/options

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
