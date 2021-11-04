import std/[os, strformat]
import ".."/[cli, logger]
import "."/[exercises, sync_common]

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
  SourceDestPair = object
    source: string
    dest: string

proc addPairIfNonIdenticalAfterHeader(sdPairs: var seq[SourceDestPair],
                                      source, dest, slug, filename: string;
                                      seenUnsynced: var set[SyncKind]) =
  ## Prints a message that describes whether the files at `source` and `dest`
  ## have identical contents.
  # TODO: Optimize this.
  if contentsAfterFirstHeader(source) == contentsAfterFirstHeader(dest):
    logDetailed(&"[skip] {slug}: {filename} is up-to-date")
  else:
    logNormal(&"[warn] {slug}: {filename} is unsynced")
    seenUnsynced.incl skDocs
    sdPairs.add SourceDestPair(source: source, dest: dest)

proc addUnsyncedIntroductionPaths(sdPairs: var seq[SourceDestPair];
                                  slug, trackDocsDir, psExerciseDir: string;
                                  seenUnsynced: var set[SyncKind]) =
  # If the exercise in problem-specifications has an `introduction.md`
  # file, the track exercise must have a `.docs/introduction.md` file.
  const introFilename = "introduction.md"
  let psIntroPath = psExerciseDir / introFilename
  if fileExists(psIntroPath):
    let trackIntroPath = trackDocsDir / introFilename
    if fileExists(trackIntroPath):
      addPairIfNonIdenticalAfterHeader(sdPairs, psIntroPath, trackIntroPath,
                                       slug, introFilename, seenUnsynced)
    else:
      logNormal(&"[error] {slug}: {introFilename} is missing")
      seenUnsynced.incl skDocs

proc addUnsyncedInstructionsPaths(sdPairs: var seq[SourceDestPair];
                                  slug, trackDocsDir, psExerciseDir: string;
                                  seenUnsynced: var set[SyncKind]) =
  # The track exercise must have a `.docs/instructions.md` file.
  # Its contents should match those of the corresponding `instructions.md`
  # file in problem-specifications (or `description.md` if that file
  # doesn't exist).
  const instrFilename = "instructions.md"
  let trackInstrPath = trackDocsDir / instrFilename
  if fileExists(trackInstrPath):
    const descFilename = "description.md"
    let psInstrPath = psExerciseDir / instrFilename
    let psDescPath = psExerciseDir / descFilename
    if fileExists(psInstrPath):
      addPairIfNonIdenticalAfterHeader(sdPairs, psInstrPath, trackInstrPath,
                                       slug, instrFilename, seenUnsynced)
    elif fileExists(psDescPath):
      addPairIfNonIdenticalAfterHeader(sdPairs, psDescPath, trackInstrPath,
                                       slug, instrFilename, seenUnsynced)
    else:
      logNormal(&"[error] {slug}: does not have an upstream " &
                &"{instrFilename} or {descFilename} file")
      seenUnsynced.incl skDocs
  else:
    logNormal(&"[warn] {slug}: {instrFilename} is missing")
    seenUnsynced.incl skDocs

proc checkOrUpdateDocs*(seenUnsynced: var set[SyncKind];
                        conf: Conf;
                        trackPracticeExercisesDir: string;
                        exercises: seq[Exercise];
                        psExercisesDir: string) =
  ## Prints a message for each Practice Exercise on the track with an outdated
  ## `.docs/introduction.md` or `.docs/instructions.md` file, and updates them
  ## if `--update` was passed and the user confirms.
  ##
  ## Includes `skDocs` in `seenUnsynced` if there are still such unsynced files
  ## afterwards.
  var sdPairs = newSeq[SourceDestPair]()

  for exercise in exercises:
    let slug = exercise.slug.string
    let trackDocsDir = joinPath(trackPracticeExercisesDir, slug, ".docs")

    if not dirExists(trackDocsDir):
      if conf.action.update:
        createDir(trackDocsDir)
      seenUnsynced.incl skDocs

    # Get pairs of unsynced paths
    let psExerciseDir = psExercisesDir / slug
    if dirExists(psExerciseDir):
      sdPairs.addUnsyncedIntroductionPaths(slug, trackDocsDir, psExerciseDir, seenUnsynced)
      sdPairs.addUnsyncedInstructionsPaths(slug, trackDocsDir, psExerciseDir, seenUnsynced)
    else:
      logDetailed(&"[skip] {slug}: does not exist in problem-specifications")

  # Update docs
  if conf.action.update and sdPairs.len > 0:
    if conf.action.yes or userSaysYes(skDocs):
      for sdPair in sdPairs:
        # TODO: don't replace first top-level header?
        # For example: the below currently writes `# Description`
        # instead of `# Instructions`
        doAssert lastPathPart(sdPair.dest) in ["instructions.md", "introduction.md"]
        copyFile(sdPair.source, sdPair.dest)
      seenUnsynced.excl skDocs
