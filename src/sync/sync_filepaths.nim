import std/[os, strformat, strutils]
import pkg/jsony
import ".."/[cli, logger]
import "."/sync_common

func replace(slug: Slug, sub: char, by: char): string {.borrow.}

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

template genCond(field: untyped) =
  patterns.field.len == 0 or (f.field.len > 0 and f.field != [""])

func isSynced(f: ConceptExerciseFiles | PracticeExerciseFiles,
              patterns: FilePatterns): bool =
  # Returns `true` if every field of `f` is either non-empty or cannot be synced
  # from the corresponding field in `patterns`.
  let uniqueCond =
    when f is ConceptExerciseFiles:
      genCond(exemplar)
    else:
      genCond(example)
  uniqueCond and genCond(solution) and genCond(test) and genCond(editor)

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

proc init(T: typedesc[ExerciseConfig], kind: ExerciseKind,
          trackExerciseConfigPath: string): T =
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
      logDetailed(&"[skip] filepaths: up-to-date: {slug}")
    else:
      let padding = if conf.verbosity == verDetailed: "  " else: ""
      logNormal(&"[warn] filepaths: unsynced: {padding}{slug}") # Aligns slug.
      seenUnsynced.incl skFilepaths
      update(exerciseConfig, filePatterns, slug)
      configPairs.add PathAndUpdatedExerciseConfig(path: trackExerciseConfigPath,
                                                   exerciseConfig: exerciseConfig)
  else:
    let metaDir = trackExerciseConfigPath.parentDir()
    if dirExists(metaDir):
      logNormal(&"[warn] filepaths: missing .meta/config.json: {slug}")
    else:
      logNormal(&"[warn] filepaths: missing .meta directory: {slug}")
    seenUnsynced.incl skFilepaths
    if conf.action.update:
      var exerciseConfig = ExerciseConfig(kind: exerciseKind)
      update(exerciseConfig, filePatterns, slug)
      configPairs.add PathAndUpdatedExerciseConfig(path: trackExerciseConfigPath,
                                                   exerciseConfig: exerciseConfig)

proc write(configPairs: seq[PathAndUpdatedExerciseConfig]) =
  for configPair in configPairs:
    let path = configPair.path
    if path.endsWith(&".meta{DirSep}config.json"):
      createDir path.parentDir()
      let contents =
        case configPair.exerciseConfig.kind
        of ekConcept:
          configPair.exerciseConfig.c.pretty(prettyMode = pmSync)
        of ekPractice:
          configPair.exerciseConfig.p.pretty(prettyMode = pmSync)
      writeFile(path, contents)
    else:
      stderr.writeLine &"Unexpected path before writing: {path}"
      quit 1
  let s = if configPairs.len > 1: "s" else: ""
  logNormal(&"Updated the filepaths for {configPairs.len} exercise{s}")

proc checkOrUpdateFilepaths*(seenUnsynced: var set[SyncKind];
                             conf: Conf;
                             conceptExerciseSlugs: seq[Slug];
                             practiceExerciseSlugs: seq[Slug];
                             filePatterns: FilePatterns;
                             trackPracticeExercisesDir: string;
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
  var configPairs = newSeq[PathAndUpdatedExerciseConfig]()

  for exerciseKind in [ekConcept, ekPractice]:
    let slugs =
      case exerciseKind
      of ekConcept: conceptExerciseSlugs
      of ekPractice: practiceExerciseSlugs
    var trackExerciseConfigPath =
      case exerciseKind
      of ekConcept: trackConceptExercisesDir
      of ekPractice: trackPracticeExercisesDir
    normalizePathEnd(trackExerciseConfigPath, trailingSep = true)
    let startLen = trackExerciseConfigPath.len

    for slug in slugs:
      trackExerciseConfigPath.truncateAndAdd(startLen, slug)
      trackExerciseConfigPath.addExerciseConfigPath()
      addUnsyncedFilepaths(configPairs, conf, exerciseKind, slug,
                           trackExerciseConfigPath, filePatterns,
                           seenUnsynced)

  # For each item in `configPairs`, write the JSON to the corresponding path.
  # If successful, excludes `skFilepaths` from `seenUnsynced`.
  if conf.action.update and configPairs.len > 0:
    if conf.action.yes or userSaysYes(skFilepaths):
      write(configPairs)
      seenUnsynced.excl skFilepaths
