import std/[os, strformat, strscans, strutils, terminal]
import ".."/[cli, helpers]

proc writeError(description, path: string) =
  let descriptionPrefix = description & ":"
  if colorStdout:
    stdout.styledWriteLine(fgRed, descriptionPrefix)
  else:
    stdout.writeLine(descriptionPrefix)
  stdout.writeLine(path)
  stdout.write "\n"

proc conceptIntroduction(conf: Conf, slug: string, templateFilePath: Path): string =
  let conceptDir = conf.trackDir / "concepts" / slug
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
      writeError(&"File {path} not found for concept '{slug}'", $templateFilePath)
      quit(1)
  else:
    writeError(&"Directory {conceptDir} not found for concept '{slug}'", $templateFilePath)
    quit(1)

proc generateIntroduction(conf: Conf, templateFilePath: Path): string =
  let content = readFile(templateFilePath)
  
  var idx = 0
  while idx < content.len:
    var conceptSlug = ""
    if scanp(content, idx, 
            "%{", *{' ', '\t'}, "concept", *{' ', '\t'}, ':', *{' ', '\t'},
            +{'a'..'z', '-'} -> conceptSlug.add($_), *{' ', '\t'}, '}'):
      result.add(conceptIntroduction(conf, conceptSlug, templateFilePath))
    else:
      result.add(content[idx])
      inc idx

proc generate*(conf: Conf) =
  let trackDir = Path(conf.trackDir)

  let conceptExercisesDir = trackDir / "exercises" / "concept"
  if dirExists(conceptExercisesDir):
    for conceptExerciseDir in getSortedSubdirs(conceptExercisesDir):
      let introductionTemplateFilePath = conceptExerciseDir / ".docs" / "introduction.md.tpl"
      if fileExists(introductionTemplateFilePath):
        let introduction = generateIntroduction(conf, introductionTemplateFilePath)
        let introductionFilePath = conceptExerciseDir / ".docs" / "introduction.md"
        writeFile(introductionFilePath, introduction)
