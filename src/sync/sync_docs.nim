import std/[os, strformat, strutils]
import ".."/[cli, logger]
import "."/sync_common

type
  PathAndContents = object
    path: string
    contents: string

func addAndIncl(pairsToWrite: var seq[PathAndContents];
                path, contents: string;
                seenUnsynced: var set[SyncKind]) =
  ## Appends the `path` and `contents` pair to `pairsToWrite`, and includes
  ## `skDocs` in `seenUnsynced`.
  pairsToWrite.add PathAndContents(path: path, contents: contents)
  seenUnsynced.incl skDocs

type
  ProbSpecsSourceKind = enum
    psskInstr = "instructions"
    psskDesc = "description"
    psskIntro = "introduction"

proc getPsSourceContents(psSourcePath: string;
                         pssk: ProbSpecsSourceKind): string =
  ## Reads `psSourceContents`, but if `pssk == psskDesc`, a starting
  ## "# Description" header is replaced with an "# Instructions" header.
  const descHeader = "# Description\n"
  result = readFile(psSourcePath)

  if pssk == psskDesc and result.startsWith(descHeader):
    const instrHeader = "# Instructions\n"
    # Replace header.
    result.setLen result.len + instrHeader.len - descHeader.len
    for i in countdown(result.high, descHeader.len):
      result[i] = result[i-1]
    for i, c in instrHeader:
      result[i] = instrHeader[i]

proc addUnsyncedImpl(pairsToWrite: var seq[PathAndContents];
                     psSourcePath, trackDestPath: string;
                     conf: Conf;
                     slug: Slug;
                     pssk: ProbSpecsSourceKind;
                     seenUnsynced: var set[SyncKind]) =
  ## Given a `psSourcePath` which is known to exist, appends to `pairsToWrite`
  ## if the corresponding file at `trackDestPath` is unsynced.
  let psSourceContents = getPsSourceContents(psSourcePath, pssk)
  let psskStr = if pssk == psskDesc: psskInstr else: pssk
  if psSourceContents.len == 0:
    logNormal(&"[error] docs: empty source file: {psSourcePath}")
  elif fileExists(trackDestPath):
    let trackDestContents = readFile(trackDestPath)
    if trackDestContents == psSourceContents:
      logDetailed(&"[skip] docs: {psskStr} up-to-date: {slug}")
    else:
      let padding = if conf.verbosity == verDetailed: "  " else: ""
      logNormal(&"[warn] docs: {psskStr} unsynced: {padding}{slug}") # Aligns slug.
      pairsToWrite.addAndIncl(trackDestPath, psSourceContents, seenUnsynced)
  else:
    let docsDirPath = trackDestPath.parentDir()
    if dirExists(docsDirPath): # e.g. /foo/zig/exercises/practice/bob/.docs
      logNormal(&"[warn] docs: {psskStr} missing: {slug}")
    else:
      logNormal(&"[warn] docs: missing .meta directory: {slug}")
      if conf.action.update:
        createDir(docsDirPath)
    pairsToWrite.addAndIncl(trackDestPath, psSourceContents, seenUnsynced)

func toPath(pssk: ProbSpecsSourceKind): string =
  &"{DirSep}{pssk}.md"

proc addUnsynced(pairsToWrite: var seq[PathAndContents];
                 psSourcePath, trackDestPath: var string;
                 conf: Conf;
                 slug: Slug;
                 seenUnsynced: var set[SyncKind]) =
  ## Appends to `pairsToWrite` if the file at `trackDestPath` is unsynced with
  ## the file at `psSourcePath`.
  let psStartLen = psSourcePath.len
  let trackStartLen = trackDestPath.len
  const pathInstr = toPath(psskInstr)
  psSourcePath.add pathInstr # e.g. /foo/problem-specifications/exercises/bob/instructions.md
  trackDestPath.add pathInstr # e.g. /foo/zig/exercises/practice/bob/.docs/instructions.md

  # The track exercise must have a `.docs/instructions.md` file.
  # Its contents should match those of the corresponding `instructions.md` file
  # in problem-specifications (or `description.md` if that file doesn't exist).
  # So first, check against an upstream `instructions.md` file
  if fileExists(psSourcePath):
    addUnsyncedImpl(pairsToWrite, psSourcePath, trackDestPath, conf, slug,
                    psskInstr, seenUnsynced)
  else:
    # No upstream `instructions.md` - check against an upstream `description.md` file.
    const pathDesc = toPath(psskDesc)
    psSourcePath.setLen(psStartLen)
    psSourcePath.add pathDesc # e.g. /foo/problem-specifications/exercises/bob/description.md
    if fileExists(psSourcePath):
      addUnsyncedImpl(pairsToWrite, psSourcePath, trackDestPath, conf, slug,
                      psskDesc, seenUnsynced)
    else:
      logNormal(&"[error] docs: missing upstream {psskInstr} or {psskDesc} " &
                &"file: {slug}")

  # The track exercise must have a `.docs/introduction.md` file if
  # the problem-specifications exercise has an `introduction.md` file.
  psSourcePath.setLen psStartLen # e.g. /foo/problem-specifications/exercises/bob
  const pathIntro = toPath(psskIntro)
  psSourcePath.add pathIntro # e.g. /foo/problem-specifications/exercises/bob/introduction.md
  if fileExists(psSourcePath):
    trackDestPath.setLen trackStartLen
    trackDestPath.add pathIntro # e.g. /foo/zig/exercises/practice/bob/.docs/introduction.md
    addUnsyncedImpl(pairsToWrite, psSourcePath, trackDestPath, conf, slug,
                    psskIntro, seenUnsynced)

proc write(pairsToWrite: seq[PathAndContents]) =
  ## Writes to each `item.path` with `item.contents`.
  for pathAndContents in pairsToWrite:
    let path = pathAndContents.path
    doAssert lastPathPart(path) in [$psskInstr & ".md", $psskIntro & ".md"]
    writeFile(path, pathAndContents.contents)
  let s = if pairsToWrite.len > 1: "s" else: ""
  logNormal(&"Updated the docs for {pairsToWrite.len} Practice Exercise{s}")

proc checkOrUpdateDocs*(seenUnsynced: var set[SyncKind];
                        conf: Conf;
                        practiceExerciseSlugs: seq[Slug];
                        trackPracticeExercisesDir: string;
                        psExercisesDir: string) =
  ## Prints a message for each Practice Exercise on the track with an outdated
  ## `.docs/introduction.md` or `.docs/instructions.md` file, and updates them
  ## if `--update` was passed and the user confirms.
  ##
  ## Includes `skDocs` in `seenUnsynced` if there are still such unsynced files
  ## afterwards.
  var pairsToWrite = newSeq[PathAndContents]()
  var psSourcePath = normalizePathEnd(psExercisesDir, trailingSep = true)
  let psStartLen = psSourcePath.len
  var trackDestPath = normalizePathEnd(trackPracticeExercisesDir, trailingSep = true)
  let trackDestStartLen = trackDestPath.len

  for slug in practiceExerciseSlugs:
    psSourcePath.truncateAndAdd(psStartLen, slug)
    if dirExists(psSourcePath): # e.g. /foo/problem-specifications/exercises/bob
      trackDestPath.truncateAndAdd(trackDestStartLen, slug)
      trackDestPath.addDocsDir()
      addUnsynced(pairsToWrite, psSourcePath, trackDestPath, conf, slug, seenUnsynced)
    else:
      logDetailed(&"[skip] docs: exercise does not exist in " &
                  &"problem-specifications: {slug}")

  # Update docs
  if conf.action.update and pairsToWrite.len > 0:
    if conf.action.yes or userSaysYes(skDocs):
      write(pairsToWrite)
      seenUnsynced.excl skDocs
