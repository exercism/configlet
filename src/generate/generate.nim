import std/[os, parseutils, strbasics, strformat, strscans, strutils, sugar,
            tables, terminal]
import ".."/[cli, helpers, logger, types_track_config]

type
  PathAndGeneratedDocument = object
    path: string
    generatedDocument: string

proc getConceptSlugLookup(trackDir: Path): Table[Slug, string] =
  ## Returns a `Table` that maps each concept's `slug` to its `name`.
  let concepts = TrackConfig.init(readFile(trackDir / "config.json")).concepts
  collect:
    for con in concepts:
      {con.slug.Slug: con.name}

func alterHeadings(s: string, linkDefs: var seq[string], h2 = ""): string =
  result = newStringOfCap(s.len)
  var i = 0
  i += s.skipWhitespace()
  # Skip the top-level heading (if any).
  # The CommonMark Spec requires that an ATX heading has a a space, tab, or
  # newline after the opening sequence of '#' characters.
  # For now, support only spaces.
  if s.continuesWith("# ", i):
    i += s.skipUntil('\n', i)
  if h2.len > 0:
    result.add &"## {h2}"
  # Demote other headings.
  var inFencedCodeBlock = false
  var inFencedCodeBlockTildes = false
  var inCommentBlock = false
  while i < s.len:
    result.add s[i]
    if s[i] == '\n':
      # Add a '#' to a line that begins with '#', unless inside a code or HTML block.
      if s.continuesWith("#", i+1) and not (inFencedCodeBlock or
                                            inFencedCodeBlockTildes or inCommentBlock):
        result.add '#'
      elif s.continuesWith("[", i+1) and not (inFencedCodeBlock or
                                              inFencedCodeBlockTildes or inCommentBlock):
        let j = s.find("]:", i+2)
        if j > i+2 and j < s.find('\n', i+2):
          var line = ""
          i += s.parseUntil(line, '\n', i+1)
          if line notin linkDefs:
            linkDefs.add line
      elif s.continuesWith("```", i+1):
        inFencedCodeBlock = not inFencedCodeBlock
      elif s.continuesWith("~~~", i+1):
        inFencedCodeBlockTildes = not inFencedCodeBlockTildes
      elif s.continuesWith("<!--", i+1):
        inCommentBlock = true
    elif inCommentBlock and s.continuesWith("-->", i):
      inCommentBlock = false
    inc i
  strip result

proc writeError(description: string, path: Path) =
  let descriptionPrefix = description & ":"
  if colorStderr:
    stderr.styledWriteLine(fgRed, descriptionPrefix)
  else:
    stderr.writeLine(descriptionPrefix)
  stderr.writeLine(path)
  stderr.write "\n"

proc conceptIntroduction(trackDir: Path, slug: Slug, templatePath: Path,
                         linkDefs: var seq[string], h2 = ""): string =
  ## Returns the contents of the `introduction.md` file for a `slug`, but:
  ## - Without a first top-level heading.
  ## - Adding a starting a second-level heading containing `h2`.
  ## - Demoting the level of any other heading.
  ## - Without any leading/trailing whitespace.
  ## - Without any link reference definitions.
  ##
  ## Appends link reference definitions to `linkDefs`.
  let conceptDir = trackDir / "concepts" / slug.string
  if dirExists(conceptDir):
    let path = conceptDir / "introduction.md"
    if fileExists(path):
      result = path.readFile().alterHeadings(linkDefs, h2)
    else:
      writeError(&"File {path} not found for concept '{slug}'", templatePath)
      quit QuitFailure
  else:
    writeError(&"Directory {conceptDir} not found for concept '{slug}'",
               templatePath)
    quit QuitFailure

proc generateIntroduction(trackDir: Path, templatePath: Path,
                          slugLookup: Table[Slug, string]): string =
  ## Reads the file at `templatePath` and returns the content of the
  ## corresponding `introduction.md` file.
  let content = readFile(templatePath)
  result = newStringOfCap(1024)

  var i = 0
  var headingLevel = 1
  var linkDefs = newSeq[string]()
  while i < content.len:
    var cs = "" # Buffer for a concept slug that may not be valid.
    # Here, we implement the syntax for a placeholder as %{concept:some-slug}
    # where we allow spaces after the opening brace, around the colon,
    # and before the closing brace.
    #
    # The slug must be in kebab-case, matching the regular expression:
    #
    #   ^[a-z0-9]+(-[a-z0-9]+)*$
    #
    # `configlet lint` enforces this for slugs in the track config.json file.
    if scanp(content, i,
             "%{", *{' '}, "concept", *{' '}, ':', *{' '},
             +{'a'..'z', '0'..'9', '-'} -> cs.add($_), *{' '}, '}'):
      if cs[0] == '-' or cs[^1] == '-' or "--" in cs:
        writeError(&"Concept '{cs}' is invalid. A slug cannot start or end " &
                    "with a '-', or contain consecutive '-' characters",
                    templatePath)
      let conceptSlug = Slug(cs)
      if conceptSlug in slugLookup:
        let h2 = if headingLevel == 2: "" else: slugLookup[conceptSlug]
        result.add conceptIntroduction(trackDir, conceptSlug, templatePath,
                                       linkDefs, h2)
      else:
        writeError(&"Concept '{conceptSlug}' does not exist in track config.json",
                   templatePath)
        quit QuitFailure
    else:
      if content.continuesWith("\n#", i):
        headingLevel = content.skipWhile({'#'}, i+1)
      result.add content[i]
      inc i
  result.strip()
  result.add '\n'
  if linkDefs.len > 0:
    result.add '\n'
    for linkDef in linkDefs:
      result.add linkDef
      result.add '\n'

iterator getIntroductionTemplatePaths(trackDir: Path, conf: Conf): Path =
  let conceptExercisesDir = trackDir / "exercises" / "concept"
  if dirExists(conceptExercisesDir):
    for conceptExerciseDir in getSortedSubdirs(conceptExercisesDir):
      if conf.action.exerciseGenerate.len == 0 or conf.action.exerciseGenerate == $conceptExerciseDir.splitFile.name:
        let introductionTemplatePath = conceptExerciseDir / ".docs" / "introduction.md.tpl"
        if fileExists(introductionTemplatePath):
          yield introductionTemplatePath

proc generateImpl(trackDir: Path, conf: Conf): seq[PathAndGeneratedDocument] =
  result = @[]

  let slugLookup = getConceptSlugLookup(trackDir)

  for introductionTemplatePath in getIntroductionTemplatePaths(trackDir, conf):
    let generated = generateIntroduction(trackDir, introductionTemplatePath,
                                         slugLookup)
    let introductionPath = introductionTemplatePath.string[0..^5] # Removes `.tpl`

    if fileExists(introductionPath):
      if readFile(introductionPath) == generated:
        logDetailed(&"Up-to-date: {relativePath(introductionPath, $trackDir)}")
      else:
        logNormal(&"Outdated: {relativePath(introductionPath, $trackDir)}")
        result.add PathAndGeneratedDocument(
          path: introductionPath,
          generatedDocument: generated
        )
    else:
      logNormal(&"Missing: {relativePath(introductionPath, $trackDir)}")
      result.add PathAndGeneratedDocument(
        path: introductionPath,
        generatedDocument: generated
      )

proc writeGenerated(generatedPairs: seq[PathAndGeneratedDocument]) =
  for generatedPair in generatedPairs:
    let path = generatedPair.path
    doAssert lastPathPart(path) == "introduction.md"
    createDir path.parentDir()
    logDetailed(&"Generating: {path}")
    writeFile(path, generatedPair.generatedDocument)
  let s = if generatedPairs.len > 1: "s" else: ""
  logNormal(&"Generated {generatedPairs.len} file{s}")

proc userSaysYes(userExercise: string): bool =
  ## Asks the user if they want to format files, and returns `true` if they
  ## confirm.
  let s = if userExercise.len > 0: "" else: "s"
  while true:
    stderr.write &"Generate (update) the above file{s} ([y]es/[n]o)? "
    case stdin.readLine().toLowerAscii()
    of "y", "yes":
      return true
    of "n", "no":
      return false
    else:
      stderr.writeLine "Unrecognized response. Please answer [y]es or [n]o."

proc generate*(conf: Conf) =
  ## For every Concept Exercise in `conf.trackDir` with an `introduction.md.tpl`
  ## file, write the corresponding `introduction.md` file.
  let trackDir = Path(conf.trackDir)
  let pairs = generateImpl(trackDir, conf)

  let userExercise = conf.action.exerciseGenerate
  if pairs.len > 0:
    if conf.action.updateGenerate:
      if conf.action.yesGenerate or userSaysYes(userExercise):
        writeGenerated(pairs)
      else:
        quit QuitFailure
    else:
      quit QuitFailure
  else:
    let wording =
      if userExercise.len > 0:
        &"The `{userExercise}`"
      else:
        "Every"
    logNormal(&"{wording} introduction file is up-to-date!")
