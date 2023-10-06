import std/[os, strformat, strutils]
import ".."/[fmt/articles, helpers, sync/sync_common, types_track_config,
             types_articles_config, uuid/uuid]

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

proc createArticle*(articleSlug: Slug, exerciseSlug: Slug,
    exerciseDir: string) =
  let articlesDir = exerciseDir / ".articles"
  let configPath = articlesDir / "config.json"

  if not dirExists(articlesDir):
    createDir(articlesDir)

  var config =
    if not fileExists(configPath):
      ArticlesConfig(
        articles: newSeq[ArticleConfig]()
      )
    else:
      parseFile(configPath, ArticlesConfig)

  var articleExists = false

  for article in config.articles:
    if $articleSlug == article.slug:
      articleExists = true
      break

  let title = kebabToTitleCase(articleSlug)

  if not articleExists:
    config.articles.add ArticleConfig(
      uuid: $genUuid(),
      slug: $articleSlug,
      title: title,
      blurb: "",
      authors: newSeq[string]()
    )

    let formattedConfig = prettyArticlesConfig(config)
    writeFile(configPath, formattedConfig)

  let articleDir = articlesDir / $articleSlug
  if not dirExists(articleDir):
    createDir(articleDir)

  let contentPath = articleDir / "content.md"
  let snippetPath = articleDir / "snippet.md"

  if not fileExists(contentPath):
    writeFile(contentPath, &"# {title}\n\n")

  if not fileExists(snippetPath):
    writeFile(snippetPath, "")

  echo &"Created article '{articleSlug}' for the exercise '{exerciseSlug}'."
