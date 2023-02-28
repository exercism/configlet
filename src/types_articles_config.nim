import std/options

type
  ArticleConfig* = object
    uuid*: string
    slug*: string
    title*: string
    blurb*: string
    authors*: seq[string]
    contributors*: Option[seq[string]]

  ArticlesConfig* = object
    articles*: seq[ArticleConfig]
