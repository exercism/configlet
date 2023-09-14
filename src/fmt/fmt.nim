import std/[os, strformat, strutils]
import "."/[approaches, articles, exercises]
import ".."/[cli, helpers, logger, sync/sync_common, sync/sync,
    types_exercise_config, types_track_config]

type
  DocumentKind* = enum
    dkTrackConfig,
    dkConceptExerciseConfig,
    dkPracticeExerciseConfig,
    dkApproachesConfig,
    dkArticlesConfig

  PathAndFormattedDocument = object
    kind: DocumentKind
    path: string
    formattedDocument: string

iterator getConfigPaths(trackExerciseSlugs: TrackExerciseSlugs,
                        trackDir: string): (DocumentKind, string) =
  ## Yield the track's `config.json` file
  yield (dkTrackConfig, trackDir / "config.json")

  ## Yields the `.meta/config.json`, `.approaches/config.json` and
  ## `.articles/config.json` paths for each exercise in
  ## `trackExerciseSlugs` in `trackExercisesDir`.
  let trackExercisesDir = trackDir / "exercises"
  for exerciseKind in [ekConcept, ekPractice]:
    let documentKind =
      case exerciseKind
      of ekConcept: dkConceptExerciseConfig
      of ekPractice: dkPracticeExerciseConfig
    let slugs =
      case exerciseKind
      of ekConcept: trackExerciseSlugs.`concept`
      of ekPractice: trackExerciseSlugs.practice
    var trackExerciseConfigPath =
      case exerciseKind
      of ekConcept: trackExercisesDir / "concept"
      of ekPractice: trackExercisesDir / "practice"
    normalizePathEnd(trackExerciseConfigPath, trailingSep = true)
    let startLen = trackExerciseConfigPath.len

    for slug in slugs:
      trackExerciseConfigPath.truncateAndAdd(startLen, slug)
      trackExerciseConfigPath.addExerciseConfigPath()
      yield (documentKind, trackExerciseConfigPath)

      trackExerciseConfigPath.truncateAndAdd(startLen, slug)
      trackExerciseConfigPath.addApproachesConfigPath()
      if fileExists(trackExerciseConfigPath):
        yield (dkApproachesConfig, trackExerciseConfigPath)

      trackExerciseConfigPath.truncateAndAdd(startLen, slug)
      trackExerciseConfigPath.addArticlesConfigPath()
      if fileExists(trackExerciseConfigPath):
        yield (dkArticlesConfig, trackExerciseConfigPath)

proc fmtImpl(trackExerciseSlugs: TrackExerciseSlugs,
             trackDir: string): seq[PathAndFormattedDocument] =
  ## Reads the track config file and all exercise config files
  ## for every slug in `trackExerciseSlugs` in `trackExerciseDir`.
  ## This includes `.meta/config.json`, `.approaches/config.json`
  ## and `.articles/config.json` for each exercise, and `config.json`
  ## for the track.
  ##
  ## Returns a seq of (document kind, path, formatted document) objects
  ## containing every exercise's configs that are not already formatted.
  var seenUnformatted = false
  for (documentKind, configPath) in getConfigPaths(trackExerciseSlugs,
                                                   trackDir):
    let formatted =
      case documentKind
      of dkTrackConfig: formatTrackConfigFile(configPath)
      of dkConceptExerciseConfig: formatExerciseConfigFile(ekConcept, configPath)
      of dkPracticeExerciseConfig: formatExerciseConfigFile(ekPractice, configPath)
      of dkApproachesConfig: formatApproachesConfigFile(configPath)
      of dkArticlesConfig: formatArticlesConfigFile(configPath)

    # TODO: remove duplicate `readFile`.
    if fileExists(configPath) and readFile(configPath) == formatted:
      logDetailed(&"Already formatted: {relativePath(configPath, trackDir)}")
    else:
      if not seenUnformatted:
        logNormal(&"The below paths are relative to '{trackDir}'")
      seenUnformatted = true
      logNormal(&"Not formatted: {relativePath(configPath, trackDir)}")
      result.add PathAndFormattedDocument(
        kind: documentKind,
        path: configPath,
        formattedDocument: formatted
      )

proc userSaysYes(userExercise: string): bool =
  ## Asks the user if they want to format files, and returns `true` if they
  ## confirm.
  let s = if userExercise.len > 0: "" else: "s"
  while true:
    stderr.write &"Format the above file{s} ([y]es/[n]o)? "
    case stdin.readLine().toLowerAscii()
    of "y", "yes":
      return true
    of "n", "no":
      return false
    else:
      stderr.writeLine "Unrecognized response. Please answer [y]es or [n]o."

proc writeFormatted(prettyPairs: seq[PathAndFormattedDocument]) =
  for prettyPair in prettyPairs:
    let path = prettyPair.path
    doAssert lastPathPart(path) == "config.json"
    createDir path.parentDir()
    logDetailed(&"Writing formatted: {path}")
    writeFile(path, prettyPair.formattedDocument)
  let s = if prettyPairs.len > 1: "s" else: ""
  logNormal(&"Formatted {prettyPairs.len} file{s}")

proc fmt*(conf: Conf) =
  ## Prints a list of `.meta/config.json` paths in `conf.trackDir` where the
  ## config file is missing or not in the canonical form, and formats them if
  ## the user confirms.
  let trackConfigPath = conf.trackDir / "config.json"
  let trackConfig = parseFile(trackConfigPath, TrackConfig)
  logNormal(&"Found {trackConfig.exercises.`concept`.len} Concept Exercises " &
            &"and {trackConfig.exercises.practice.len} Practice Exercises in " &
            trackConfigPath)
  let trackExerciseSlugs = getSlugs(trackConfig.exercises, conf, trackConfigPath)
  logNormal("Looking for exercises that lack a formatted '.meta/config.json', " &
            "'.approaches/config.json'\nor '.articles/config.json' file...")

  let pairs = fmtImpl(trackExerciseSlugs, conf.trackDir)

  let userExercise = conf.action.exerciseFmt
  if pairs.len > 0:
    if conf.action.updateFmt:
      if conf.action.yesFmt or userSaysYes(userExercise):
        writeFormatted(pairs)
      else:
        quit 1
    else:
      quit 1
  else:
    let wording =
      if userExercise.len > 0:
        &"The `{userExercise}`"
      else:
        "Every"
    logNormal(&"{wording} exercise config is already formatted!")
