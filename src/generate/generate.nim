import std/[parseutils, strbasics, strformat, strscans, strutils, tables, terminal]
import ".."/[cli, helpers, types_track_config]

proc getSlugLookup(trackDir: Path): Table[string, string] =
  let concepts = TrackConfig.init(readFile(trackDir / "config.json")).concepts
  result = initTable[string, string](concepts.len)
  for `concept` in concepts:
    result[`concept`.slug] = `concept`.name

proc writeError(description: string, path: Path) =
  let descriptionPrefix = description & ":"
  if colorStderr:
    stderr.styledWriteLine(fgRed, descriptionPrefix)
  else:
    stderr.writeLine(descriptionPrefix)
  stderr.writeLine(path)
  stderr.write "\n"

func alterHeaders(s: string, title: string, headerLevel: int): string =
  # Markdown implementations differ on whether a space is required after the
  # final '#' character that begins the header.
  result = newStringOfCap(s.len)
  var i = 0
  i += s.skipWhitespace()
  # Skip the top-level header (if any)
  if s.continuesWith("# ", i):
    i += s.skipUntil('\n', i)
  if headerLevel == 1:
    result.add &"## {title}"
  # Demote other headers
  var inFencedCodeBlock = false
  var inCommentBlock = false
  while i < s.len:
    result.add s[i]
    if s[i] == '\n':
      # Add a '#' to a line that begins with '#', unless inside a code or HTML block.
      if s.continuesWith("#", i+1) and not (inFencedCodeBlock or inCommentBlock):
        let demotionAmount = if headerLevel in [1, 2]: 1 else: headerLevel - 1
        for _ in 1..demotionAmount:
          result.add '#'
      elif s.continuesWith("```", i+1):
        inFencedCodeBlock = not inFencedCodeBlock
      elif s.continuesWith("<!--", i+1):
        inCommentBlock = true
    elif inCommentBlock and s.continuesWith("-->", i):
      inCommentBlock = false
    inc i
  strip result

proc conceptIntroduction(trackDir: Path, slug: string, title: string,
                         templatePath: Path, headerLevel: int): string =
  ## Returns the contents of the `introduction.md` file for a `slug`, but:
  ## - Without a first top-level header.
  ## - Adding a starting a second-level header containing `title`.
  ## - Demoting the level of any other header.
  ## - Without any leading/trailing whitespace.
  let conceptDir = trackDir / "concepts" / slug
  if dirExists(conceptDir):
    let path = conceptDir / "introduction.md"
    if fileExists(path):
      result = path.readFile().alterHeaders(title, headerLevel)
    else:
      writeError(&"File {path} not found for concept '{slug}'", templatePath)
      quit(1)
  else:
    writeError(&"Directory {conceptDir} not found for concept '{slug}'",
               templatePath)
    quit(1)

proc generateIntroduction(trackDir: Path, templatePath: Path,
                          slugLookup: Table[string, string]): string =
  ## Reads the file at `templatePath` and returns the content of the
  ## corresponding `introduction.md` file.
  let content = readFile(templatePath)
  result = newStringOfCap(1024)

  var i = 0
  var headerLevel = 1
  while i < content.len:
    var conceptSlug = ""
    # Here, we implement the syntax for a placeholder as %{concept:some-slug}
    # where we allow spaces after the opening brace, around the colon,
    # and before the closing brace. The slug must be in kebab-case.
    if scanp(content, i,
             "%{", *{' '}, "concept", *{' '}, ':', *{' '},
             +{'a'..'z', '-'} -> conceptSlug.add($_), *{' '}, '}'):
      let title = slugLookup[conceptSlug]
      result.add conceptIntroduction(trackDir, conceptSlug, title, templatePath,
                                     headerLevel)
    else:
      if content.continuesWith("\n#", i):
        headerLevel = content.skipWhile({'#'}, i+1)
      result.add content[i]
      inc i

proc generate*(conf: Conf) =
  ## For every Concept Exercise in `conf.trackDir` with an `introduction.md.tpl`
  ## file, write the corresponding `introduction.md` file.
  let trackDir = Path(conf.trackDir)

  let conceptExercisesDir = trackDir / "exercises" / "concept"
  if dirExists(conceptExercisesDir):
    let slugLookup = getSlugLookup(trackDir)
    for conceptExerciseDir in getSortedSubdirs(conceptExercisesDir):
      let introductionTemplatePath = conceptExerciseDir / ".docs" / "introduction.md.tpl"
      if fileExists(introductionTemplatePath):
        let introduction = generateIntroduction(trackDir, introductionTemplatePath,
                                                slugLookup)
        let introductionPath = introductionTemplatePath.string[0..^5] # Removes `.tpl`
        writeFile(introductionPath, introduction)
