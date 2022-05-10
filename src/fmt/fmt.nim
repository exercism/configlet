import std/[os, strformat, strutils]
import ".."/[cli, logger, sync/sync_common, sync/sync_filepaths, sync/sync, types_track_config]

type
  PathAndFormattedExerciseConfig = object
    path: string
    formattedExerciseConfig: string

iterator getConfigPaths(trackExerciseSlugs: TrackExerciseSlugs,
                        trackExercisesDir: string): (ExerciseKind, string) =
  ## Yields the `.meta/config.json` path for each exercise in
  ## `trackExerciseSlugs` in `trackExercisesDir`.
  for exerciseKind in [ekConcept, ekPractice]:
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
      yield (exerciseKind, trackExerciseConfigPath)

proc formatFile(exerciseKind: ExerciseKind,
                configPath: string): string =
  ## Parses the `.meta/config.json` file at `configPath` and returns it in the
  ## canonical form.
  let exerciseConfig = ExerciseConfig.init(exerciseKind, configPath)
  case exerciseKind
  of ekConcept:
    pretty(exerciseConfig.c, pmFmt)
  of ekPractice:
    pretty(exerciseConfig.p, pmFmt)

proc fmtImpl(trackExerciseSlugs: TrackExerciseSlugs,
             trackDir: string): seq[PathAndFormattedExerciseConfig] =
  ## Reads the `.meta/config.json` file for every slug in `trackExerciseSlugs`
  ## in `trackExerciseDir`.
  ##
  ## Returns a seq of (path, formatted config) objects containing every exercise
  ## config that is not already formatted.
  let trackExercisesDir = trackDir / "exercises"
  var seenUnformatted = false
  for (exerciseKind, configPath) in getConfigPaths(trackExerciseSlugs,
                                                   trackExercisesDir):
    let formatted = formatFile(exerciseKind, configPath)
    # TODO: remove duplicate `readFile`.
    if fileExists(configPath) and readFile(configPath) == formatted:
      logDetailed(&"Already formatted: {relativePath(configPath, trackDir)}")
    else:
      if not seenUnformatted:
        logNormal(&"The below paths are relative to '{trackDir}'")
      seenUnformatted = true
      logNormal(&"Not formatted: {relativePath(configPath, trackDir)}")
      result.add PathAndFormattedExerciseConfig(
        path: configPath,
        formattedExerciseConfig: formatted
      )

proc userSaysYes(userExercise: string): bool =
  ## Asks the user if they want to format files, and returns `true` if they
  ## confirm.
  let s = if userExercise.len > 0: "" else: "s"
  while true:
    stderr.write &"Format the above exercise config{s} ([y]es/[n]o)? "
    case stdin.readLine().toLowerAscii()
    of "y", "yes":
      return true
    of "n", "no":
      return false
    else:
      stderr.writeLine "Unrecognized response. Please answer [y]es or [n]o."

proc writeFormatted(prettyPairs: seq[PathAndFormattedExerciseConfig]) =
  for prettyPair in prettyPairs:
    let path = prettyPair.path
    doAssert lastPathPart(path) == "config.json"
    createDir path.parentDir()
    logDetailed(&"Writing formatted: {path}")
    writeFile(path, prettyPair.formattedExerciseConfig)
  let s = if prettyPairs.len > 1: "s" else: ""
  logNormal(&"Formatted the exercise config for {prettyPairs.len} exercise{s}")

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
  logNormal("Looking for exercises that lack a formatted '.meta/config.json' " &
            "file...")

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
