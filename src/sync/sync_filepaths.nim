import std/[algorithm, os, strformat, strutils]
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

func kebabToCamelOrPascal(s: string, capitalizeFirstLetter: bool): string =
  result = newStringOfCap(s.len)
  var capitalizeNext = capitalizeFirstLetter
  for c in s:
    if c == '-':
      capitalizeNext = true
    else:
      result.add(if capitalizeNext: toUpperAscii(c) else: c)
      capitalizeNext = false

func kebabToCamel(s: string): string =
  kebabToCamelOrPascal(s, capitalizeFirstLetter = false)

func kebabToPascal(s: string): string =
  kebabToCamelOrPascal(s, capitalizeFirstLetter = true)

func toFilepathsImpl(patterns: seq[string], slug: string): seq[string] =
  result = newSeq[string](patterns.len)
  for i, pattern in patterns:
    result[i] = pattern.multiReplace(
      ("%{snake_slug}", slug.replace('-', '_')),
      ("%{kebab_slug}", slug),
      ("%{camel_slug}", slug.kebabToCamel()),
      ("%{pascal_slug}", slug.kebabToPascal())
    )

func update(f: var ConceptExerciseFiles, patterns: FilePatterns, slug: string) =
  f.solution = toFilepathsImpl(patterns.solution, slug)
  f.test = toFilepathsImpl(patterns.test, slug)
  f.exemplar = toFilepathsImpl(patterns.exemplar, slug)
  f.editor = toFilepathsImpl(patterns.editor, slug)

func update(f: var PracticeExerciseFiles, patterns: FilePatterns, slug: string) =
  f.solution = toFilepathsImpl(patterns.solution, slug)
  f.test = toFilepathsImpl(patterns.test, slug)
  f.example = toFilepathsImpl(patterns.example, slug)
  f.editor = toFilepathsImpl(patterns.editor, slug)

proc addUnsyncedFilepaths(configPairs: var seq[PathAndUpdatedExerciseConfig],
                          conf: Conf,
                          exerciseKind: ExerciseKind,
                          slug: string,
                          trackExerciseConfigPath: string,
                          filePatterns: FilePatterns,
                          seenUnsynced: var set[SyncKind]) =
  if fileExists(trackExerciseConfigPath):
    var exerciseConfig =
      case exerciseKind
      of ekConcept:
        ExerciseConfig(
          kind: exerciseKind,
          c: parseFile(trackExerciseConfigPath, ConceptExerciseConfig)
        )
      of ekPractice:
        ExerciseConfig(
          kind: exerciseKind,
          p: parseFile(trackExerciseConfigPath, PracticeExerciseConfig)
        )

    let filepathsAreSynced =
      case exerciseKind
      of ekConcept:
        let filesBefore = exerciseConfig.c.files
        update(exerciseConfig.c.files, filePatterns, slug)
        filesBefore == exerciseConfig.c.files
      of ekPractice:
        let filesBefore = exerciseConfig.p.files
        update(exerciseConfig.p.files, filePatterns, slug)
        filesBefore == exerciseConfig.p.files

    if filepathsAreSynced:
      logDetailed(&"[skip] {slug}: filepaths are up to date")
    else:
      logNormal(&"[warn] {slug}: filepaths are unsynced")
      seenUnsynced.incl skFilepaths
      configPairs.add PathAndUpdatedExerciseConfig(path: trackExerciseConfigPath,
                                                  exerciseConfig: exerciseConfig)

  else:
    let metaDir = trackExerciseConfigPath.parentDir()
    if dirExists(metaDir):
      logNormal(&"[warn] {slug}: `.meta/config.json` is missing")
    else:
      logNormal(&"[warn] {slug}: `.meta` directory is missing")
      if conf.action.update:
        createDir(metaDir)
    seenUnsynced.incl skFilepaths
    if conf.action.update:
      var exerciseConfig = ExerciseConfig()
      case exerciseKind
      of ekConcept:
        update(exerciseConfig.c.files, filePatterns, slug)
      of ekPractice:
        update(exerciseConfig.p.files, filePatterns, slug)
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
        let trackExerciseConfigPath = joinPath(dir, slug, ".meta", configFilename)
        addUnsyncedFilepaths(configPairs, conf, exerciseKind, slug,
                             trackExerciseConfigPath, trackConfig.files,
                             seenUnsynced)

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
