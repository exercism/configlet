import std/[strformat, strscans, strutils, terminal]
import ".."/[cli, helpers]

proc writeError(description: string, path: Path) =
  let descriptionPrefix = description & ":"
  if colorStderr:
    stderr.styledWriteLine(fgRed, descriptionPrefix)
  else:
    stderr.writeLine(descriptionPrefix)
  stderr.writeLine(path)
  stderr.write "\n"

proc conceptIntroduction(trackDir: Path, slug: string, templatePath: Path): string =
  let conceptDir = trackDir / "concepts" / slug
  if dirExists(conceptDir):
    let path = conceptDir / "introduction.md"
    if fileExists(path):
      let content = readFile(path)
      var idx = 0
      # Strip the top-level heading (if any)
      if scanp(content, idx, *{' ', '\t', '\v', '\c', '\n', '\f'}, "#", +' ', +(~'\n')):
        result = content.substr(idx).strip
      else:
        result = content.strip
    else:
      writeError(&"File {path} not found for concept '{slug}'", templatePath)
      quit(1)
  else:
    writeError(&"Directory {conceptDir} not found for concept '{slug}'", templatePath)
    quit(1)

proc generateIntroduction(trackDir: Path, templatePath: Path): string =
  let content = readFile(templatePath)

  var idx = 0
  while idx < content.len:
    var conceptSlug = ""
    if scanp(content, idx,
            "%{", *{' ', '\t'}, "concept", *{' ', '\t'}, ':', *{' ', '\t'},
            +{'a'..'z', '-'} -> conceptSlug.add($_), *{' ', '\t'}, '}'):
      result.add conceptIntroduction(trackDir, conceptSlug, templatePath)
    else:
      result.add content[idx]
      inc idx

proc generate*(conf: Conf) =
  let trackDir = Path(conf.trackDir)

  let conceptExercisesDir = trackDir / "exercises" / "concept"
  if dirExists(conceptExercisesDir):
    for conceptExerciseDir in getSortedSubdirs(conceptExercisesDir):
      let introductionTemplatePath = conceptExerciseDir / ".docs" / "introduction.md.tpl"
      if fileExists(introductionTemplatePath):
        let introduction = generateIntroduction(trackDir, introductionTemplatePath)
        let introductionPath = conceptExerciseDir / ".docs" / "introduction.md"
        writeFile(introductionPath, introduction)
