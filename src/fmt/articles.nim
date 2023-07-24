import std/[json, strformat]
import ".."/[helpers, sync/sync_common, types_articles_config]

func articlesConfigKeyOrderForFmt(e: ArticlesConfig): seq[ArticlesConfigKey] =
  result = @[]
  if e.articles.len > 0:
    result.add ackArticles

func addArticle(result: var string; val: ArticleConfig; indentLevel = 1) =
  ## Appends the pretty-printed JSON for an `article` object with value `val` to
  ## `result`.
  result.addNewlineAndIndent(indentLevel)
  result.add "{"
  result.addString("uuid", val.uuid, indentLevel + 1)
  result.addString("slug", val.slug, indentLevel + 1)
  result.addString("title", val.title, indentLevel + 1)
  result.addString("blurb", val.blurb, indentLevel + 1)
  result.addArray("authors", val.authors, indentLevel + 1)
  if val.contributors.len > 0:
    result.addArray("contributors", val.contributors, indentLevel + 1)
  result.removeComma()
  result.addNewlineAndIndent(indentLevel)
  result.add "},"

func addArticles(result: var string; val: seq[ArticleConfig]; indentLevel = 1) =
  ## Appends the pretty-printed JSON for an `articles` key with value `val` to
  ## `result`.
  result.addNewlineAndIndent(indentLevel)
  escapeJson("articles", result)
  result.add ": ["
  for article in val:
    result.addArticle(article, indentLevel + 1)
  result.removeComma()
  result.addNewlineAndIndent(indentLevel)
  result.add "]"

func prettyArticlesConfig(e: ArticlesConfig): string =
  ## Serializes `e` as pretty-printed JSON, using the canonical key order.
  let keys = articlesConfigKeyOrderForFmt(e)

  result = newStringOfCap(1000)
  result.add '{'
  for key in keys:
    case key
    of ackArticles:
      if e.articles.len > 0:
        result.addArticles(e.articles)
  result.removeComma()
  result.add "\n}\n"

proc formatArticlesConfigFile*(configPath: string): string =
  ## Parses the `.articles/config.json` file at `configPath` and
  ## returns it in the canonical form.
  let articlesConfig = ArticlesConfig.init(configPath)
  prettyArticlesConfig(articlesConfig)
