import std/[os, strformat, strscans, strutils]
import pkg/jsony
import ".."/[cli, logger]
import "."/[exercises, sync_common]

# Ignore the styleCheck warning for `source_url`.
{.push hint[Name]:off.}

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
  result = UpstreamMetadata()
  var key, val: string
  var i = 1
  for line in path.lines:
    # TODO: Improve this hacky TOML parsing - the below doesn't support e.g.
    # - inline comments
    # - multiline strings
    # - literal strings
    # - whitespace after values
    if line.scanf("$w$s=$s\"$+", key, val):
      if val[^1] == '"':
        val.setLen(val.len - 1)
        val = val.replace("\\", "")
        if key == "blurb":
          result.blurb = val
        elif key == "source":
          result.source = val
        elif key == "source_url":
          result.source_url = val
        elif key != "title":
          logNormal(&"[error] unexpected key/value pair:\n{path}({i}): {line}")
    elif line.len > 0:
      logNormal(&"[error] unexpected line:\n{path}({i}): {line}")
    inc i

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
                 conf: Conf;
                 slug, psMetadataTomlPath, trackExerciseConfigPath: string;
                 seenUnsynced: var set[SyncKind]) =
  ## Includes `skMetadata` in `seenUnsynced` if the given
  ## `trackExerciseConfigPath` is unsynced with `psMetadataTomlPath`.
  ##
  ## Adds to `configPairs` if `--update` was passed.
  if fileExists(psMetadataTomlPath):
    if fileExists(trackExerciseConfigPath):
      let upstreamMetadata = parseMetadataToml(psMetadataTomlPath)
      var p = parseFile(trackExerciseConfigPath, PracticeExerciseConfig)

      if metadataAreUpToDate(p, upstreamMetadata):
        logDetailed(&"[skip] {slug}: metadata are up-to-date")
      else:
        logNormal(&"[warn] {slug}: metadata are unsynced")
        seenUnsynced.incl skMetadata
        if conf.action.update:
          update(p, upstreamMetadata)
          configPairs.add PathAndUpdatedConfig(path: trackExerciseConfigPath,
                                               practiceExerciseConfig: p)
    else:
      logNormal(&"[warn] {slug}: {trackExerciseConfigPath} is missing")
      seenUnsynced.incl skMetadata
      if conf.action.update:
        let upstreamMetadata = parseMetadataToml(psMetadataTomlPath)
        var p = PracticeExerciseConfig()
        update(p, upstreamMetadata)
        configPairs.add PathAndUpdatedConfig(path: trackExerciseConfigPath,
                                             practiceExerciseConfig: p)
  else:
    logNormal(&"[error] {slug}: {psMetadataTomlPath} is missing")

proc checkOrUpdateMetadata*(seenUnsynced: var set[SyncKind];
                            conf: Conf;
                            trackPracticeExercisesDir: string;
                            exercises: seq[Exercise];
                            psExercisesDir: string) =
  ## Prints a message for each Practice Exercise on the track with an outdated
  ## `.meta/config.json` file, and updates them if `--update` was passed and the
  ## user confirms.
  ##
  ## Includes `skMetadata` in `seenUnsynced` if there are still such unsynced
  ## files afterwards.
  var configPairs = newSeq[PathAndUpdatedConfig]()

  for exercise in exercises:
    let slug = exercise.slug.string
    let trackMetaDir = joinPath(trackPracticeExercisesDir, slug, ".meta")

    if dirExists(trackMetaDir):
      let psExerciseDir = psExercisesDir / slug
      if dirExists(psExerciseDir):
        const metadataFilename = "metadata.toml"
        const configFilename = "config.json"
        let psMetadataTomlPath = psExerciseDir / metadataFilename
        let trackExerciseConfigPath = trackMetaDir / configFilename
        addUnsynced(configPairs, conf, slug, psMetadataTomlPath,
                    trackExerciseConfigPath, seenUnsynced)
      else:
        logDetailed(&"[skip] {slug}: does not exist in problem-specifications")
    else:
      logNormal(&"[error] {slug}: .meta dir missing")
      seenUnsynced.incl skMetadata

  # For each item in `configPairs`, write the JSON to the corresponding path.
  # If successful, exclude `syncKind` from `seenUnsynced`.
  if conf.action.update and configPairs.len > 0:
    if conf.action.yes or userSaysYes(skMetadata):
      for configPair in configPairs:
        writeFile(configPair.path,
                  configPair.practiceExerciseConfig.toJson() & "\n")
      seenUnsynced.excl skMetadata
