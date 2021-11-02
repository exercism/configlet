import std/[algorithm, os, sets, strformat, strscans, strutils]
import pkg/jsony
import ".."/[cli, logger]
import "."/sync_common

type
  ConceptExercise = object
    slug: string

  PracticeExercise = object
    slug: string

  Exercises = object
    `concept`: seq[ConceptExercise]
    practice: seq[PracticeExercise]

  TrackConfig = object
    exercises: Exercises
    files: FilePatterns

func getSlugs(e: seq[ConceptExercise] | seq[PracticeExercise]): seq[string] =
  ## Returns a seq of the slugs `e`, in alphabetical order.
  result = newSeq[string](e.len)
  for i, item in e:
    result[i] = item.slug
  sort result

when false:
  proc foo(trackConfig: TrackConfig, exerciseConfig: PracticeExerciseConfig | ConceptExerciseConfig) =
    # TODO: Handle multiple placeholder patterns (present on `swift` track)
    if fStrVal.scanf("$*%{$+}$*", s1, s2, s3):
      const validPlaceholders = [
        "snake_slug", "kebab_slug",
        "camel_slug", "pascal_slug"].toHashSet()
      if s1.len > 0 and s1[0] == '/':
        let msg = &"Error: `files.{key}` contains non-relative pattern: " &
                  &"`{fStrVal}`:\n{path}"
        stderr.writeLine msg
        quit(1)
      else:
        if s2 in validPlaceholders:
          result.add fStrVal
        else:
          let msg = &"Error: `files.{key}` contains invalid pattern: " &
                    &"`{fStrVal}`:\n{path}"
          stderr.writeLine msg
          quit(1)
    else:
      result.add fStrVal

func snakeToCamelOrPascal(s: string, capitalizeFirstLetter: bool): string =
  result = newStringOfCap(s.len)
  var capitalizeNext = capitalizeFirstLetter
  for c in s:
    if c == '_':
      capitalizeNext = true
    else:
      result.add(if capitalizeNext: toUpperAscii(c) else: c)
      capitalizeNext = false

func snakeToCamel(s: string): string =
  snakeToCamelOrPascal(s, capitalizeFirstLetter = false)

func snakeToPascal(s: string): string =
  snakeToCamelOrPascal(s, capitalizeFirstLetter = true)

when false:
  proc toFilenames(slug: string, patterns: seq[string]): JsonNode =
    # Returns a `JArray` of `JString` corresponding to the `patterns`.
    result = newJArray()
    for pattern in patterns:
      result.add pattern.multiReplace(
        ("%{snake_slug}", slug),
        ("%{kebab_slug}", slug.replace('_', '-')),
        ("%{camel_slug}", slug.snakeToCamel),
        ("%{pascal_slug}", slug.snakeToPascal)
      ).newJString()

proc addUnsyncedFilepaths(configPairs: var seq[PathAndUpdatedExerciseConfig],
                          conf: Conf,
                          exerciseKind: ExerciseKind,
                          slug: string,
                          trackExerciseConfigPath: string,
                          filePatterns: FilePatterns,
                          seenUnsynced: var set[SyncKind]) =
  when false:
    const conceptKeys = ["solution", "test", "exemplar"]
    const practiceKeys = ["solution", "test", "example"]
    let keys =
      case exerciseKind
      of ekConcept: conceptKeys
      of ekPractice: practiceKeys
    if fileExists(trackExerciseConfigPath):
      var exerciseConfig = parseFile(trackExerciseConfigPath, ExerciseConfig)

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
      else:
        logNormal(&"[warn] {slug}: filepaths are unsynced")
        seenUnsynced.incl skFilepaths
        if conf.action.update:
          for fieldName, fieldVal in fieldPairs(filePatterns):
            if fieldName in keys:
              j["files"][fieldName] = toFilenames(slug, fieldVal)
          configPairs.add PathAndUpdatedExerciseConfig(path: trackExerciseConfigPath,
                                                       exerciseConfig: j)

    else:
      logNormal(&"[warn] {slug}: {trackExerciseConfigPath} is missing")
      seenUnsynced.incl skFilepaths
      if conf.action.update:
        var exerciseConfig = ExerciseConfig()
        update(exerciseConfig, trackConfig)
        configPairs.add PathAndUpdatedExerciseConfig(path: trackExerciseConfigPath,
                                                     exerciseConfig: exerciseConfig)

proc checkOrUpdateFilepaths*(seenUnsynced: var set[SyncKind];
                             conf: Conf;
                             trackPracticeExercisesDir: string,
                             trackConceptExercisesDir: string) =
  ## Prints a message for each exercise on the track that has a
  ## `.meta/config.json` file containing `files` values that are unsynced with
  ## the track `config.json` file, and updates them if `--update` was passed and
  ## the user confirms.
  ##
  ## Includes `skFilepaths` in `seenUnsynced` if there are still such unsynced
  ## files afterwards.
  const configFilename = "config.json"
  let trackConfigPath = conf.trackDir / configFilename

  if fileExists(trackConfigPath):
    let trackConfig = parseFile(trackConfigPath, TrackConfig)
    var configPairs = newSeq[PathAndUpdatedExerciseConfig]()

    for exerciseKind in [ekConcept, ekPractice]:
      let slugs =
        case exerciseKind
        of ekConcept: getSlugs(trackConfig.exercises.`concept`)
        of ekPractice: getSlugs(trackConfig.exercises.practice)
      let dir =
        case exerciseKind
        of ekConcept: trackConceptExercisesDir
        of ekPractice: trackPracticeExercisesDir

      for slug in slugs:
        let trackMetaDir = joinPath(dir, slug, ".meta")

        if dirExists(trackMetaDir):
          let trackExerciseConfigPath = trackMetaDir / configFilename
          addUnsyncedFilepaths(configPairs, conf, exerciseKind, slug,
                               trackExerciseConfigPath, trackConfig.files,
                               seenUnsynced)
        else:
          logNormal(&"[error] {slug}: .meta dir missing")
          seenUnsynced.incl skFilepaths

    # For each item in `configPairs`, write the JSON to the corresponding path.
    # If successful, excludes `skFilepaths` from `seenUnsynced`.
    if conf.action.update and configPairs.len > 0:
      if conf.action.yes or userSaysYes(skFilepaths):
        for configPair in configPairs:
          writeFile(configPair.path,
                    configPair.exerciseConfig.toJson() & "\n")
        seenUnsynced.excl skFilepaths

  else:
    stderr.writeLine &"Error: file does not exist:\n {trackConfigPath}"
    quit(1)
