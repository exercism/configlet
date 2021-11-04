import std/[algorithm, os, strformat, strutils]
import pkg/jsony
import ".."/[cli, lint/validators, logger]
import "."/sync_common

type
  Slug = distinct string # A kebab-case string.

  ConceptExercise = object
    slug: Slug

  PracticeExercise = object
    slug: Slug

  Exercises = object
    `concept`: seq[ConceptExercise]
    practice: seq[PracticeExercise]

  TrackConfig = object
    exercises: Exercises
    files: FilePatterns

func `==`(x, y: Slug): bool {.borrow.}
func `<`(x, y: Slug): bool {.borrow.}
func replace(slug: Slug, sub: char, by: char): string {.borrow.}
func len(slug: Slug): int {.borrow.}
func `$`(slug: Slug): string {.borrow.}

proc parseHook(s: string, i: var int, v: var Slug) =
  ## Quits with an error message if a `slug` value is not a kebab-case string.
  var x: string
  parseHook(s, i, x)
  if not x.isKebabCase():
    let msg = &"Error: the track `config.json` file contains " &
              &"an exercise slug of \"{x}\", which is not a kebab-case string"
    stderr.writeLine msg
    quit 1
  v = cast[Slug](x)

func getSlugs(e: seq[ConceptExercise] | seq[PracticeExercise]): seq[Slug] =
  ## Returns a seq of the slugs `e`, in alphabetical order.
  result = newSeq[Slug](e.len)
  for i, item in e:
    result[i] = item.slug
  sort result

func kebabToSnake(slug: Slug): string =
  slug.replace('-', '_')

func kebabToCamelOrPascal(slug: Slug, capitalizeFirstLetter: bool): string =
  result = newStringOfCap(slug.len)
  var capitalizeNext = capitalizeFirstLetter
  for c in slug.string:
    if c == '-':
      capitalizeNext = true
    else:
      result.add(if capitalizeNext: toUpperAscii(c) else: c)
      capitalizeNext = false

func kebabToCamel(slug: Slug): string =
  kebabToCamelOrPascal(slug, capitalizeFirstLetter = false)

func kebabToPascal(slug: Slug): string =
  kebabToCamelOrPascal(slug, capitalizeFirstLetter = true)

func toFilepathsImpl(patterns: seq[string], slug: Slug): seq[string] =
  result = newSeq[string](patterns.len)
  for i, pattern in patterns:
    result[i] = pattern.multiReplace(
      ("%{snake_slug}", slug.kebabToSnake()),
      ("%{kebab_slug}", slug.string),
      ("%{camel_slug}", slug.kebabToCamel()),
      ("%{pascal_slug}", slug.kebabToPascal())
    )

func update(f: var ConceptExerciseFiles, patterns: FilePatterns, slug: Slug) =
  f.solution = toFilepathsImpl(patterns.solution, slug)
  f.test = toFilepathsImpl(patterns.test, slug)
  f.exemplar = toFilepathsImpl(patterns.exemplar, slug)
  f.editor = toFilepathsImpl(patterns.editor, slug)

func update(f: var PracticeExerciseFiles, patterns: FilePatterns, slug: Slug) =
  f.solution = toFilepathsImpl(patterns.solution, slug)
  f.test = toFilepathsImpl(patterns.test, slug)
  f.example = toFilepathsImpl(patterns.example, slug)
  f.editor = toFilepathsImpl(patterns.editor, slug)

proc addUnsyncedFilepaths(configPairs: var seq[PathAndUpdatedExerciseConfig],
                          conf: Conf,
                          exerciseKind: ExerciseKind,
                          slug: Slug,
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
        let trackExerciseConfigPath = joinPath(dir, slug.string, ".meta", configFilename)
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
