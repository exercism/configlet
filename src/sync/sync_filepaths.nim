import std/[algorithm, json, os, sets, strformat, strscans, strutils]
import ".."/[cli, logger]

type
  FilePatterns = object
    solution: seq[string]
    test: seq[string]
    example: seq[string]
    exemplar: seq[string]
    editor: seq[string]

proc handleField(files: JsonNode; fieldName, path: string; s1, s2, s3: var string): seq[string] =
  let key = fieldName
  if files.hasKey(key):
    if files[key].kind == JArray:
      for f in files[key]:
        if f.kind == JString:
          let fStrVal = f.str
          if fStrVal.len > 0:
            if fStrVal.scanf("$*%{$+}$*", s1, s2, s3):
              const validPlaceholders = [
                "snake_slug", "kebab_slug",
                "camel_slug", "pascal_slug"].toHashSet()
              if s1.len > 0 and s1[0] == '/':
                let msg = &"Error: `files.{key}` contains non-relative pattern: `{fStrVal}`:\n{path}"
                stderr.writeLine msg
                quit(1)
              else:
                if s2 in validPlaceholders:
                  result.add fStrVal
                else:
                  let msg = &"Error: `files.{key}` contains invalid pattern: `{fStrVal}`:\n{path}"
                  stderr.writeLine msg
                  quit(1)
            else:
              result.add fStrVal
          else:
            stderr.writeLine &"Error: `files.{key}` contains empty string:\n{path}"
            quit(1)
        else:
          stderr.writeLine &"Error: `files.{key}` contains a non-string: `{f}`:\n{path}"
          quit(1)
    else:
      stderr.writeLine &"Error: value of `files.{key}` is not an array: {files[key]}:\n{path}"
      quit(1)

proc getFilePatterns(trackConfig: JsonNode, path: string): FilePatterns =
  if trackConfig.hasKey("files"):
    let files = trackConfig["files"]
    if files.kind == JObject:
      var s1, s2, s3: string
      result = FilePatterns()
      for fieldName, fieldVal in fieldPairs(result):
        fieldVal = handleField(files, fieldName, path, s1, s2, s3)
  else:
    logNormal(&"[error] file does not have a `files` key:\n{path}")

type
  ExerciseKind = enum
    ekConcept = "concept"
    ekPractice = "practice"

proc getExerciseSlugs(trackConfig: JsonNode, path: string,
                      exerciseKind: ExerciseKind): seq[string] =
  ## Returns a seq of the Concept Exercise slugs in `j`, in alphabetical order.
  if trackConfig.hasKey("exercises"):
    let exercises = trackConfig["exercises"]
    let ekStr = $exerciseKind
    if exercises.hasKey(ekStr):
      let e = exercises[ekStr]
      result = newSeqOfCap[string](e.len)

      for exercise in e:
        if exercise.hasKey("slug"):
          if exercise["slug"].kind == JString:
            let slug = exercise["slug"].str
            result.add slug
  else:
    stderr.writeLine &"Error: file does not have an `exercises` key:\n{path}"
    quit(1)

  sort result

type
  CaseKind = enum
    ckCamel, ckPascal

func snakeToCamelOrPascal(s: string, caseKind: CaseKind): string =
  result = newStringOfCap(s.len)
  var capitalizeNext =
    case caseKind
    of ckCamel: false
    of ckPascal: true
  for c in s:
    if c == '_':
      capitalizeNext = true
    else:
      result.add(if capitalizeNext: toUpperAscii(c) else: c)
      capitalizeNext = false

func snakeToCamel(s: string): string {.inline.} =
  s.snakeToCamelOrPascal(ckCamel)

func snakeToPascal(s: string): string {.inline.} =
  s.snakeToCamelOrPascal(ckPascal)

proc toFilenames(slug: string, patterns: seq[string]): JsonNode =
  # Returns a string corresponding to the `pattern`.
  result = newJArray()
  for pattern in patterns:
    result.add pattern.multiReplace(
      ("%{snake_slug}", slug),
      ("%{kebab_slug}", slug.replace('_', '-')),
      ("%{camel_slug}", slug.snakeToCamel),
      ("%{pascal_slug}", slug.snakeToPascal)
    ).newJString()

type
  PathAndUpdatedJson* = object
    path*: string
    updatedJson*: JsonNode

proc checkFilepathsForExercise(res: var seq[PathAndUpdatedJson], conf: Conf,
                               exerciseKind: ExerciseKind, slug: string,
                               trackExerciseConfigPath: string,
                               filePatterns: FilePatterns): bool =
  const conceptKeys = ["solution", "test", "exemplar"]
  const practiceKeys = ["solution", "test", "example"]
  let keys =
    case exerciseKind
    of ekConcept: conceptKeys
    of ekPractice: practiceKeys
  if fileExists(trackExerciseConfigPath):
    var j = json.parseFile(trackExerciseConfigPath)
    # TODO: share this code with `configlet lint`
    if j.kind == JObject:
      if j.hasKey("files"):
        let files = j["files"]
        if files.kind == JObject:
          var numKeysAlreadyUpToDate = 0
          for key in keys:
            if files.hasKey(key):
              if files[key].kind == JArray:
                if files[key].len > 0:
                  for file in files[key]:
                    if file.kind == JString:
                      discard
                  inc numKeysAlreadyUpToDate
          if numKeysAlreadyUpToDate == keys.len:
            logDetailed(&"[skip] {slug}: filepaths are up to date")
            result = true
          else:
            logNormal(&"[warn] {slug}: filepaths are unsynced")
            if conf.action.update:
              for fieldName, fieldVal in fieldPairs(filePatterns):
                if fieldName in keys:
                  j["files"][fieldName] = toFilenames(slug, fieldVal)
              res.add PathAndUpdatedJson(path: trackExerciseConfigPath,
                                         updatedJson: j)
  else:
    logNormal(&"[warn] {slug}: {trackExerciseConfigPath} is missing")
    if conf.action.update:
      var j = newJObject()
      j["files"] = newJObject()
      for fieldName, fieldVal in fieldPairs(filePatterns):
        if fieldName in keys:
          j["files"][fieldName] = toFilenames(slug, fieldVal)
      res.add PathAndUpdatedJson(path: trackExerciseConfigPath,
                                 updatedJson: j)

proc checkFilepaths*(conf: Conf; seenUnsynced: var set[SyncKind],
                     trackPracticeExercisesDir: string,
                     trackConceptExercisesDir: string): seq[PathAndUpdatedJson] =
  const configFilename = "config.json"
  let trackConfigPath = conf.trackDir / configFilename

  if fileExists(trackConfigPath):
    let trackConfig = json.parseFile(trackConfigPath)

    let filePatterns = getFilePatterns(trackConfig, trackConfigPath)

    for exerciseKind in [ekConcept, ekPractice]:
      let slugs =
        case exerciseKind
        of ekConcept: getExerciseSlugs(trackConfig, trackConfigPath, ekConcept)
        of ekPractice: getExerciseSlugs(trackConfig, trackConfigPath, ekPractice)
      let dir =
        case exerciseKind
        of ekConcept: trackConceptExercisesDir
        of ekPractice: trackPracticeExercisesDir

      for slug in slugs:
        let trackMetaDir = joinPath(dir, slug, ".meta")

        if dirExists(trackMetaDir):
          let trackExerciseConfigPath = trackMetaDir / configFilename
          if not checkFilepathsForExercise(result, conf, exerciseKind, slug,
                                           trackExerciseConfigPath, filePatterns):
            seenUnsynced.incl skFilepaths
        else:
          logNormal(&"[error] {slug}: .meta dir missing")
          seenUnsynced.incl skFilepaths
  else:
    stderr.writeLine &"Error: file does not exist:\n {trackConfigPath}"
    quit(1)
