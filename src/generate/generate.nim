import std/[strbasics, strformat, strscans, terminal]
import ".."/[cli, helpers]

proc writeError(description: string, path: Path) =
  let descriptionPrefix = description & ":"
  if colorStderr:
    stderr.styledWriteLine(fgRed, descriptionPrefix)
  else:
    stderr.writeLine(descriptionPrefix)
  stderr.writeLine(path)
  stderr.write "\n"

proc conceptIntroduction(trackDir: Path, slug: string,
                         templatePath: Path): string =
  ## Returns the contents of the `introduction.md` file for a `slug`, but
  ## without any top-level heading, and without any leading/trailing whitespace.
  let conceptDir = trackDir / "concepts" / slug
  if dirExists(conceptDir):
    let path = conceptDir / "introduction.md"
    if fileExists(path):
      result = readFile(path)
      var i = 0
      # Strip the top-level heading (if any)
      if scanp(result, i, *{' ', '\t', '\v', '\c', '\n', '\f'}, "#", +' ',
               +(~'\n')):
        result.setSlice(i..result.high)
      strip result
    else:
      writeError(&"File {path} not found for concept '{slug}'", templatePath)
      quit(1)
  else:
    writeError(&"Directory {conceptDir} not found for concept '{slug}'",
               templatePath)
    quit(1)

proc generateIntroduction(trackDir: Path, templatePath: Path): string =
  ## Reads the file at `templatePath` and returns the content of the
  ## corresponding `introduction.md` file.
  let content = readFile(templatePath)

  var i = 0
  while i < content.len:
    var conceptSlug = ""
    # Here, we implement the syntax for a placeholder as %{concept:some-slug}
    # where we allow spaces after the opening brace, around the colon,
    # and before the closing brace. The slug must be in kebab-case.
    if scanp(content, i,
             "%{", *{' '}, "concept", *{' '}, ':', *{' '},
             +{'a'..'z', '-'} -> conceptSlug.add($_), *{' '}, '}'):
      result.add conceptIntroduction(trackDir, conceptSlug, templatePath)
    else:
      result.add content[i]
      inc i

proc generate*(conf: Conf) =
  ## For every Concept Exercise in `conf.trackDir` with an `introduction.md.tpl`
  ## file, write the corresponding `introduction.md` file.
  let trackDir = Path(conf.trackDir)

  let conceptExercisesDir = trackDir / "exercises" / "concept"
  if dirExists(conceptExercisesDir):
    for conceptExerciseDir in getSortedSubdirs(conceptExercisesDir):
      let introductionTemplatePath = conceptExerciseDir / ".docs" / "introduction.md.tpl"
      if fileExists(introductionTemplatePath):
        let introduction = generateIntroduction(trackDir, introductionTemplatePath)
        let introductionPath = introductionTemplatePath.string[0..^5] # Removes `.tpl`
        writeFile(introductionPath, introduction)
