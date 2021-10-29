import std/[os, strformat]
import ".."/[cli, logger]
import "."/exercises

proc contentsAfterFirstHeader(path: string): string =
  result = newStringOfCap(getFileSize(path))
  var isFirstLine = true
  for line in path.lines:
    if isFirstLine:
      if not (line.len > 2 and line[0] == '#' and line[1] == ' '):
        result.add line
        result.add '\n'
      isFirstLine = false
    else:
      result.add line
      result.add '\n'

type
  SourceDestPair* = object
    source*: string
    dest*: string

proc checkFilesIdenticalAfterHeader(source, dest, slug, filename: string;
                                    seenUnsynced: var set[SyncKind];
                                    conf: Conf;
                                    sdPairs: var seq[SourceDestPair]) =
  ## Prints a message that describes whether the files at `source` and `dest`
  ## have identical contents.
  # TODO: Optimize this.
  if contentsAfterFirstHeader(source) == contentsAfterFirstHeader(dest):
    logDetailed(&"[skip] {slug}: {filename} is up-to-date")
  else:
    logNormal(&"[warn] {slug}: {filename} is unsynced")
    seenUnsynced.incl skDocs
    if conf.action.update:
      sdPairs.add SourceDestPair(source: source, dest: dest)

proc checkIntroduction(conf: Conf;
                       slug, trackDocsDir, psExerciseDir: string;
                       seenUnsynced: var set[SyncKind];
                       sdPairs: var seq[SourceDestPair]) =
  # If the exercise in problem-specifications has an `introduction.md`
  # file, the track exercise must have a `.docs/introduction.md` file.
  let introFilename = "introduction.md"
  let psIntroPath = psExerciseDir / introFilename
  if fileExists(psIntroPath):
    let trackIntroPath = trackDocsDir / introFilename
    if fileExists(trackIntroPath):
      checkFilesIdenticalAfterHeader(psIntroPath, trackIntroPath, slug,
                                     introFilename, seenUnsynced, conf, sdPairs)
    else:
      logNormal(&"[error] {slug}: {introFilename} is missing")
      seenUnsynced.incl skDocs

proc checkInstructions(conf: Conf;
                       slug, trackDocsDir, psExerciseDir: string;
                       seenUnsynced: var set[SyncKind];
                       sdPairs: var seq[SourceDestPair]) =
  # The track exercise must have a `.docs/instructions.md` file.
  # Its contents should match those of the corresponding `instructions.md`
  # file in problem-specifications (or `description.md` if that file
  # doesn't exist).
  let instrFilename = "instructions.md"
  let trackInstrPath = trackDocsDir / instrFilename
  if fileExists(trackInstrPath):
    let descFilename = "description.md"
    let psInstrPath = psExerciseDir / instrFilename
    let psDescPath = psExerciseDir / descFilename
    if fileExists(psInstrPath):
      checkFilesIdenticalAfterHeader(psInstrPath, trackInstrPath, slug,
                                     instrFilename, seenUnsynced, conf, sdPairs)
    elif fileExists(psDescPath):
      checkFilesIdenticalAfterHeader(psDescPath, trackInstrPath, slug,
                                     instrFilename, seenUnsynced, conf, sdPairs)
    else:
      logNormal(&"[error] {slug}: does not have an upstream " &
                &"{instrFilename} or {descFilename} file")
      seenUnsynced.incl skDocs
  else:
    logNormal(&"[error] {slug}: {instrFilename} is missing")
    seenUnsynced.incl skDocs

proc checkDocs*(conf: Conf,
                seenUnsynced: var set[SyncKind],
                trackPracticeExercisesDir: string,
                exercises: seq[Exercise],
                psExercisesDir: string): seq[SourceDestPair] =
  for exercise in exercises:
    let slug = exercise.slug.string
    let trackDocsDir = joinPath(trackPracticeExercisesDir, slug, ".docs")

    if dirExists(trackDocsDir):
      let psExerciseDir = psExercisesDir / slug
      if dirExists(psExerciseDir):
        checkIntroduction(conf, slug, trackDocsDir, psExerciseDir, seenUnsynced,
                          result)
        checkInstructions(conf, slug, trackDocsDir, psExerciseDir, seenUnsynced,
                          result)
      else:
        logDetailed(&"[skip] {slug}: does not exist in problem-specifications")
    else:
      logNormal(&"[error] {slug}: .docs dir missing")
      seenUnsynced.incl skDocs
