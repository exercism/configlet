import std/options
import "."/[helpers]

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

proc init*(T: typedesc[ArticlesConfig]; articlesConfigFilePath: string): T =
  ## Deserializes contents of `articlesConfigFilePath` using `jsony` to
  ## an `ArticlesConfig` object.
  parseFile(articlesConfigFilePath, ArticlesConfig)
