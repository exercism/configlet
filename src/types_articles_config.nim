import std/options
import pkg/jsony
import "."/[cli, helpers]

type
  ArticlesConfigKey* = enum
    ackArticles = "articles"

  ArticleKey* = enum
    akUuid = "uuid"
    akSlug = "slug"
    akTitle = "title"
    akBlurb = "blurb"
    akAuthors = "authors"
    akContributors = "contributors"

  ArticleConfig* = object
    uuid*: string
    slug*: string
    title*: string
    blurb*: string
    authors*: seq[string]
    contributors*: Option[seq[string]]

  ArticlesConfig* = object
    articles*: seq[ArticleConfig]

proc init*(T: typedesc[ArticlesConfig]; articlesConfigContents: string): T =
  ## Deserializes `articlesConfigContents` using `jsony` to a `ArticlesConfig` object.
  try:
    result = fromJson(articlesConfigContents, ArticlesConfig)
  except jsony.JsonError:
    let msg = tidyJsonyErrorMsg(articlesConfigContents)
    showError(msg)
