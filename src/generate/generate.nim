import std/[parseutils, strbasics, strformat, strscans, tables, terminal]
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

func alterHeaders(s: string, title: string): string =
  # Markdown implementations differ on whether a space is required after the
  # final '#' character that begins the header.
  result = newStringOfCap(s.len)
  var i = 0
  i += s.skipWhitespace()
  # Skip the top-level header (if any)
  if i < s.len and s[i] == '#' and i+1 < s.len and s[i+1] == ' ':
    i += s.skipUntil('\n', i)
  result.add &"## {title}"
  # Demote other headers
  var inFencedCodeBlock = false
  while i < s.len:
    result.add s[i]
    if s[i] == '\n':
      # When inside a fenced code block, don't alter a line that begins with '#'
      if i+1 < s.len and s[i+1] == '#' and not inFencedCodeBlock:
        result.add '#'
      elif i+3 < s.len and s[i+1] == '`' and s[i+2] == '`' and s[i+3] == '`':
        inFencedCodeBlock = not inFencedCodeBlock
        result.add "```"
        i += 3
    inc i
  strip result

proc conceptIntroduction(trackDir: Path, slug: string, title: string,
                         templatePath: Path): string =
  ## Returns the contents of the `introduction.md` file for a `slug`, but:
  ## - Without a first top-level header.
  ## - Adding a starting a second-level header containing `title`.
  ## - Demoting the level of any other header.
  ## - Without any leading/trailing whitespace.
  let conceptDir = trackDir / "concepts" / slug
  if dirExists(conceptDir):
    let path = conceptDir / "introduction.md"
    if fileExists(path):
      result = path.readFile().alterHeaders(title)
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
  while i < content.len:
    var conceptSlug = ""
    # Here, we implement the syntax for a placeholder as %{concept:some-slug}
    # where we allow spaces after the opening brace, around the colon,
    # and before the closing brace. The slug must be in kebab-case.
    if scanp(content, i,
             "%{", *{' '}, "concept", *{' '}, ':', *{' '},
             +{'a'..'z', '-'} -> conceptSlug.add($_), *{' '}, '}'):
      let title = slugLookup[conceptSlug]
      result.add conceptIntroduction(trackDir, conceptSlug, title, templatePath)
    else:
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
