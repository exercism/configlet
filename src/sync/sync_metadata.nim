import std/[os, parseutils, strformat, strutils]
import ".."/[cli, logger]
import "."/sync_common

# Ignore the styleCheck warning for `source_url`.
{.push hint[Name]: off.}

type
  UpstreamMetadata = object
    blurb: string
    source: string
    source_url: string

  PathAndUpdatedConfig = object
    path: string
    practiceExerciseConfig: PracticeExerciseConfig

{.pop.}

func parseString(s: string, i: var int, val: var string) =
  ## Parses the TOML string starting at `s[i]` into `val`.
  inc i
  while i < s.len:
    let c = s[i]
    if c == '"':
      break
    elif c == '\\':
      inc i
      let c = s[i]
      if c in {'"', '\\'}:
        val.add c
      else:
        val.add c
    else:
      val.add c
    inc i
  inc i

proc parseMetadataToml(path: string): UpstreamMetadata =
  ## Parses the problem-specifications `metadata.toml` file at `path`, and
  ## returns an object containing the `blurb`, `source`, and `source_url` values.
  # TODO: Improve this TOML parsing. This proc doesn't currently support e.g.
  # - non-inline comments
  # - quoted keys
  # - multi-line strings
  # - literal strings
  # But as of 2021-11-01, `metadata.toml` files in `problem-specifications`
  # do not contain these.
  result = UpstreamMetadata()
  let toml = readFile(path)
  var i = 0
  var indexLineStart = 0
  var key, val: string

  while i < toml.len:
    i += skipWhile(toml, {' ', '\n'}, i)
    indexLineStart = i
    i += parseUntil(toml, key, {' ', '='}, i)
    i += skipUntil(toml, '"', i)
    parseString(toml, i, val)
    if key == "blurb":
      result.blurb = val
    elif key == "source":
      result.source = val
    elif key == "source_url":
      result.source_url = val
    elif key.len > 0 and key != "title":
      let j = min(toml.high, i)
      let line = toml[indexLineStart .. j].strip()
      logNormal(&"[error] unexpected key/value pair:\n{path}:\n{line}")
    val.setLen 0
    i += skipUntil(toml, '\n', i)

func metadataAreUpToDate(p: PracticeExerciseConfig;
                         upstreamMetadata: UpstreamMetadata): bool =
  ## Returns `true` if the values of the `blurb`, `source`, and `source_url`
  ## fields in `p` are the same as those in `upstreamMetadata`.
  p.blurb == upstreamMetadata.blurb and
      p.source == upstreamMetadata.source and
      p.source_url == upstreamMetadata.source_url

func update(p: var PracticeExerciseConfig;
            upstreamMetadata: UpstreamMetadata) =
  ## Sets the values of the `blurb`, `source`, and `source_url` fields in
  ## `p` to those in `upstreamMetadata`.
  p.blurb = upstreamMetadata.blurb
  p.source = upstreamMetadata.source
  p.source_url = upstreamMetadata.source_url

proc addUnsynced(configPairs: var seq[PathAndUpdatedConfig];
                 conf: Conf; slug: Slug;
                 psMetadataTomlPath, trackExerciseConfigPath: string;
                 seenUnsynced: var set[SyncKind]) =
  ## Includes `skMetadata` in `seenUnsynced` if the given
  ## `trackExerciseConfigPath` is unsynced with `psMetadataTomlPath`.
  ##
  ## Appends to `configPairs` if `--update` was passed.
  if fileExists(psMetadataTomlPath):
    if fileExists(trackExerciseConfigPath):
      let upstreamMetadata = parseMetadataToml(psMetadataTomlPath)
      var p = parseFile(trackExerciseConfigPath, PracticeExerciseConfig)

      if metadataAreUpToDate(p, upstreamMetadata):
        logDetailed(&"[skip] {slug}: metadata are up to date")
      else:
        logNormal(&"[warn] {slug}: metadata are unsynced")
        seenUnsynced.incl skMetadata
        if conf.action.update:
          update(p, upstreamMetadata)
          configPairs.add PathAndUpdatedConfig(path: trackExerciseConfigPath,
                                               practiceExerciseConfig: p)
    else:
      let metaDir = trackExerciseConfigPath.parentDir()
      if dirExists(metaDir):
        logNormal(&"[warn] {slug}: the `.meta/config.json` file is missing")
      else:
        logNormal(&"[warn] {slug}: the `.meta` directory is missing")
        if conf.action.update:
          createDir(metaDir)
      seenUnsynced.incl skMetadata
      if conf.action.update:
        let upstreamMetadata = parseMetadataToml(psMetadataTomlPath)
        var p = PracticeExerciseConfig()
        update(p, upstreamMetadata)
        configPairs.add PathAndUpdatedConfig(path: trackExerciseConfigPath,
                                             practiceExerciseConfig: p)
  else:
    logNormal(&"[error] {slug}: {psMetadataTomlPath} is missing")

proc write(configPairs: seq[PathAndUpdatedConfig]) =
  for configPair in configPairs:
    let updatedJson = pretty(configPair.practiceExerciseConfig)
    doAssert lastPathPart(configPair.path) == "config.json"
    writeFile(configPair.path, updatedJson)
  let s = if configPairs.len > 1: "s" else: ""
  logNormal(&"Updated the metadata for {configPairs.len} Practice Exercise{s}")

proc checkOrUpdateMetadata*(seenUnsynced: var set[SyncKind];
                            conf: Conf;
                            practiceExerciseSlugs: seq[Slug];
                            trackPracticeExercisesDir: string;
                            psExercisesDir: string) =
  ## Prints a message for each Practice Exercise on the track with an outdated
  ## `.meta/config.json` file, and updates them if `--update` was passed and the
  ## user confirms.
  ##
  ## Includes `skMetadata` in `seenUnsynced` if there are still such unsynced
  ## files afterwards.
  var configPairs = newSeq[PathAndUpdatedConfig]()

  for slug in practiceExerciseSlugs:
    let trackMetaDir = joinPath(trackPracticeExercisesDir, slug.string, ".meta")

    let psExerciseDir = psExercisesDir / slug.string
    if dirExists(psExerciseDir):
      const metadataFilename = "metadata.toml"
      const configFilename = "config.json"
      let psMetadataTomlPath = psExerciseDir / metadataFilename
      let trackExerciseConfigPath = trackMetaDir / configFilename
      addUnsynced(configPairs, conf, slug, psMetadataTomlPath,
                  trackExerciseConfigPath, seenUnsynced)
    else:
      logDetailed(&"[skip] {slug}: does not exist in problem-specifications")

  # For each item in `configPairs`, write the JSON to the corresponding path.
  # If successful, exclude `syncKind` from `seenUnsynced`.
  if conf.action.update and configPairs.len > 0:
    if conf.action.yes or userSaysYes(skMetadata):
      write(configPairs)
      seenUnsynced.excl skMetadata
