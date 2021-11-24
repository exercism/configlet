import std/[os, strformat]
import pkg/parsetoml
import ".."/[cli, logger]
import "."/sync_common

# Silence the styleCheck hint for `source_url`.
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

proc parseMetadataToml(path: string): UpstreamMetadata =
  ## Parses the problem-specifications `metadata.toml` file at `path`, and
  ## returns an object containing the `blurb`, `source`, and `source_url` values.
  let t = parsetoml.parseFile(path)
  result = UpstreamMetadata(
    blurb: if t.hasKey("blurb"): t["blurb"].getStr() else: "",
    source: if t.hasKey("source"): t["source"].getStr() else: "",
    source_url: if t.hasKey("source_url"): t["source_url"].getStr() else: ""
  )

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
  if upstreamMetadata.blurb.len > 0 and eckBlurb notin p.originalKeyOrder:
    p.originalKeyOrder.add eckBlurb
  if upstreamMetadata.source.len > 0 and eckSource notin p.originalKeyOrder:
    p.originalKeyOrder.add eckSource
  if upstreamMetadata.source_url.len > 0 and eckSourceUrl notin p.originalKeyOrder:
    p.originalKeyOrder.add eckSourceUrl

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
        logDetailed(&"[skip] metadata: up-to-date: {slug}")
      else:
        let padding = if conf.verbosity == verDetailed: "  " else: ""
        logNormal(&"[warn] metadata: unsynced: {padding}{slug}") # Aligns slug.
        seenUnsynced.incl skMetadata
        if conf.action.update:
          update(p, upstreamMetadata)
          configPairs.add PathAndUpdatedConfig(path: trackExerciseConfigPath,
                                               practiceExerciseConfig: p)
    else:
      let metaDir = trackExerciseConfigPath.parentDir()
      if dirExists(metaDir):
        logNormal(&"[warn] metadata: missing .meta/config.json file: {slug}")
      else:
        logNormal(&"[warn] metadata: missing .meta directory: {slug}")
      seenUnsynced.incl skMetadata
      if conf.action.update:
        let upstreamMetadata = parseMetadataToml(psMetadataTomlPath)
        var p = PracticeExerciseConfig()
        update(p, upstreamMetadata)
        configPairs.add PathAndUpdatedConfig(path: trackExerciseConfigPath,
                                             practiceExerciseConfig: p)
  else:
    logNormal(&"[error] metadata: {slug}: missing {psMetadataTomlPath}")

proc write(configPairs: seq[PathAndUpdatedConfig]) =
  for configPair in configPairs:
    let updatedJson = pretty(configPair.practiceExerciseConfig, pmSync)
    let path = configPair.path
    doAssert lastPathPart(path) == "config.json"
    createDir path.parentDir()
    writeFile(path, updatedJson)
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
  var psMetadataTomlPath = normalizePathEnd(psExercisesDir, trailingSep = true)
  let startLenPsPath = psMetadataTomlPath.len
  var trackExerciseConfigPath = normalizePathEnd(trackPracticeExercisesDir,
                                                 trailingSep = true)
  let startLenTrackPath = trackExerciseConfigPath.len

  for slug in practiceExerciseSlugs:
    psMetadataTomlPath.truncateAndAdd(startLenPsPath, slug)
    if dirExists(psMetadataTomlPath):
      psMetadataTomlPath.addMetadataTomlPath()
      trackExerciseConfigPath.truncateAndAdd(startLenTrackPath, slug)
      trackExerciseConfigPath.addExerciseConfigPath()
      addUnsynced(configPairs, conf, slug, psMetadataTomlPath,
                  trackExerciseConfigPath, seenUnsynced)
    else:
      logDetailed(&"[skip] metadata: exercise does not exist in " &
                  &"problem-specifications: {slug}")

  # For each item in `configPairs`, write the JSON to the corresponding path.
  # If successful, exclude `syncKind` from `seenUnsynced`.
  if conf.action.update and configPairs.len > 0:
    if conf.action.yes or userSaysYes(skMetadata):
      write(configPairs)
      seenUnsynced.excl skMetadata
