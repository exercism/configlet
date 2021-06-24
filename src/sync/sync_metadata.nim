import std/[json, os, strformat]
import pkg/parsetoml
import ".."/[cli, logger]
import "."/[exercises, sync_filepaths]

proc isThisMetadataSynced(res: var seq[PathAndUpdatedJson]; conf: Conf; slug: string;
                          psMetadataTomlPath, trackExerciseConfigPath: string): bool =
  ## Returns `true` if the values of any `blurb`, `source` and `source_url` keys
  ## in `psMetadataTomlPath` are the same as those in `trackExerciseConfigPath`.
  ##
  ## Otherwise, appends to `res` if `conf.action.update` is `true`.
  if fileExists(psMetadataTomlPath):
    const keys = ["blurb", "source", "source_url"]
    if fileExists(trackExerciseConfigPath):
      let toml = parsetoml.parseFile(psMetadataTomlPath)
      var j = json.parseFile(trackExerciseConfigPath)
      var numTomlKeys = 0
      var numKeysAlreadyUpToDate = 0

      for key in keys:
        if toml.hasKey(key):
          inc numTomlKeys
          let upstreamVal = toml[key]
          if upstreamVal.kind == TomlValueKind.String:
            if j.hasKey(key):
              let trackVal = j[key]
              if trackVal.kind == JString and (upstreamVal.stringVal == trackVal.str):
                inc numKeysAlreadyUpToDate
              elif conf.action.update:
                j[key] = newJString(upstreamVal.stringVal)
          else:
            let msg = &"value of '{key}' is `{upstreamVal}`, but it must be a string"
            logNormal(&"[error] {msg}:\n{psMetadataTomlPath}")

      if numKeysAlreadyUpToDate == numTomlKeys:
        logDetailed(&"[skip] {slug}: metadata are up-to-date")
        result = true
      else:
        logNormal(&"[warn] {slug}: metadata are unsynced")
        if conf.action.update:
          res.add PathAndUpdatedJson(path: trackExerciseConfigPath,
                                     updatedJson: j)

    else:
      logNormal(&"[warn] {slug}: {trackExerciseConfigPath} is missing")
      if conf.action.update:
        let toml = parsetoml.parseFile(psMetadataTomlPath)
        var j = newJObject()
        for key in keys:
          if toml.hasKey(key):
            let upstreamVal = toml[key]
            if upstreamVal.kind == TomlValueKind.String:
              j[key] = newJString(upstreamVal.stringVal)
              res.add PathAndUpdatedJson(path: trackExerciseConfigPath,
                                         updatedJson: j)
  else:
    logNormal(&"[error] {slug}: {psMetadataTomlPath} is missing")

proc checkMetadata*(conf: Conf,
                    seenUnsynced: var set[SyncKind],
                    trackPracticeExercisesDir: string,
                    exercises: seq[Exercise],
                    psExercisesDir: string): seq[PathAndUpdatedJson] =
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
        if not isThisMetadataSynced(result, conf, slug, psMetadataTomlPath,
                                    trackExerciseConfigPath):
          seenUnsynced.incl skMetadata
      else:
        logDetailed(&"[skip] {slug}: does not exist in problem-specifications")
    else:
      logNormal(&"[error] {slug}: .meta dir missing")
      seenUnsynced.incl skMetadata
