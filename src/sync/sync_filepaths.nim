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

proc postHook(e: ConceptExercise | PracticeExercise) =
  ## Quits with an error message if a `slug` value is not a kebab-case string.
  let s = e.slug.string
  if not isKebabCase(s):
    let msg = "Error: the track `config.json` file contains " &
              &"an exercise slug of \"{s}\", which is not a kebab-case string"
    stderr.writeLine msg
    quit 1

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

func toFilepaths(patterns: seq[string], slug: Slug): seq[string] =
  result = newSeq[string](patterns.len)
  for i, pattern in patterns:
    result[i] = pattern.multiReplace(
      ("%{snake_slug}", slug.kebabToSnake()),
      ("%{kebab_slug}", slug.string),
      ("%{camel_slug}", slug.kebabToCamel()),
      ("%{pascal_slug}", slug.kebabToPascal())
    )

func update(a: var seq[string], b: seq[string], slug: Slug) =
  if (a.len == 0 or a == @[""]) and b.len > 0:
    a = toFilepaths(b, slug)

func update(f: var (ConceptExerciseFiles | PracticeExerciseFiles),
            patterns: FilePatterns,
            slug: Slug) =
  update(f.solution, patterns.solution, slug)
  update(f.test, patterns.test, slug)
  update(f.editor, patterns.editor, slug)
  when f is ConceptExerciseFiles:
    update(f.exemplar, patterns.exemplar, slug)
  when f is PracticeExerciseFiles:
    update(f.example, patterns.example, slug)

func isSynced(f: ConceptExerciseFiles | PracticeExerciseFiles,
              patterns: FilePatterns): bool =
  # Returns `true` if every field of `f` is either non-empty or cannot be synced
  # from the corresponding field in `patterns`.
  when f is ConceptExerciseFiles:
    if patterns.exemplar.len > 0 and (f.exemplar.len == 0 or f.exemplar == [""]):
      return false
  when f is PracticeExerciseFiles:
    if patterns.example.len > 0 and (f.example.len == 0 or f.example == [""]):
      return false
  (patterns.solution.len == 0 or (f.solution.len > 0 and f.solution != [""])) and
      (patterns.test.len == 0 or (f.test.len > 0 and f.test != [""])) and
      (patterns.editor.len == 0 or (f.editor.len > 0 and f.editor != [""]))

type
  ExerciseConfig = object
    case kind: ExerciseKind
    of ekConcept:
      c: ConceptExerciseConfig
    of ekPractice:
      p: PracticeExerciseConfig

  PathAndUpdatedExerciseConfig = object
    path: string
    exerciseConfig: ExerciseConfig

proc init(T: typedesc, kind: ExerciseKind, trackExerciseConfigPath: string): T =
  case kind
  of ekConcept: T(
    kind: kind,
    c: parseFile(trackExerciseConfigPath, ConceptExerciseConfig)
  )
  of ekPractice: T(
    kind: kind,
    p: parseFile(trackExerciseConfigPath, PracticeExerciseConfig)
  )

func hasSyncedFilepaths(e: ExerciseConfig, patterns: FilePatterns): bool =
  case e.kind
  of ekConcept:
    isSynced(e.c.files, patterns)
  of ekPractice:
    isSynced(e.p.files, patterns)

func update(e: var ExerciseConfig, patterns: FilePatterns, slug: Slug) =
  case e.kind
  of ekConcept:
    update(e.c.files, patterns, slug)
  of ekPractice:
    update(e.p.files, patterns, slug)

proc addUnsyncedFilepaths(configPairs: var seq[PathAndUpdatedExerciseConfig],
                          conf: Conf,
                          exerciseKind: ExerciseKind,
                          slug: Slug,
                          trackExerciseConfigPath: string,
                          filePatterns: FilePatterns,
                          seenUnsynced: var set[SyncKind]) =
  if fileExists(trackExerciseConfigPath):
    var exerciseConfig = ExerciseConfig.init(exerciseKind, trackExerciseConfigPath)
    let filepathsAreSynced = hasSyncedFilepaths(exerciseConfig, filePatterns)
    if filepathsAreSynced:
      logDetailed(&"[skip] {slug}: filepaths are up to date")
    else:
      logNormal(&"[warn] {slug}: filepaths are unsynced")
      seenUnsynced.incl skFilepaths
      update(exerciseConfig, filePatterns, slug)
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
      var exerciseConfig = ExerciseConfig(kind: exerciseKind)
      update(exerciseConfig, filePatterns, slug)
      configPairs.add PathAndUpdatedExerciseConfig(path: trackExerciseConfigPath,
                                                   exerciseConfig: exerciseConfig)

proc write(configPairs: seq[PathAndUpdatedExerciseConfig]) =
  for configPair in configPairs:
    doAssert lastPathPart(configPair.path) == "config.json"
    case configPair.exerciseConfig.kind
    of ekConcept:
      writeFile(configPair.path, configPair.exerciseConfig.c.pretty())
    of ekPractice:
      writeFile(configPair.path, configPair.exerciseConfig.p.pretty())

proc checkOrUpdateFilepaths*(seenUnsynced: var set[SyncKind];
                             conf: Conf;
                             trackPracticeExercisesDir: string,
                             trackConceptExercisesDir: string) =
  ## Prints a message for each track exercise that:
  ## - lacks a `.meta/config.json` file
  ## - or has a `.meta/config.json` file with an missing/empty
  ##   `files.solution|test|editor|example|exemplar` array, when that value has
  ##   a pattern defined in the track-level `config.json` file.
  ##
  ## Populates those values if `--update` was passed and the user confirms.
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
        write(configPairs)
        seenUnsynced.excl skFilepaths

  else:
    stderr.writeLine &"Error: file does not exist:\n {trackConfigPath}"
    quit(1)
