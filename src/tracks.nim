import sequtils, os, parsetoml, json, sets

type
  ConfigJsonExercise = object
    slug: string

  ConfigJson = object
    exercises: seq[ConfigJsonExercise]

  TrackRepoExercise = object
    dir: string
    slug: string
    testsFile: string

  TrackRepo* = object
    dir: string
    configFile: string
    exercises: seq[TrackRepoExercise]

  TrackExerciseTest* = object
    uuid: string
    enabled: bool

  TrackExercise* = object
    slug*: string
    case hasTests: bool
    of true: 
      tests: seq[TrackExerciseTest]
    else:
      discard    

  Track* = object
    exercises*: seq[TrackExercise]

proc newTrackRepoExercise(dir: string): TrackRepoExercise =
  TrackRepoExercise(
    dir: dir,
    slug: extractFilename(dir),
    testsFile: joinPath(dir, joinPath(".meta", "tests.toml"))
  )

proc newTrackRepoExercises(dir: string): seq[TrackRepoExercise] =
  for exerciseDir in walkDirs(joinPath(dir, "exercises/*")):
    result.add(newTrackRepoExercise(exerciseDir))

proc newTrackRepo: TrackRepo =
  let dir = getCurrentDir()
  let configFile = joinPath(dir, "config.json")
  let exercises = newTrackRepoExercises(dir)
  TrackRepo(dir: dir, configFile: configFile, exercises: exercises)

proc parseTrackExerciseTests(trackRepoExercise: TrackRepoExercise): seq[TrackExerciseTest] =
  let toml = parsetoml.parseFile(trackRepoExercise.testsFile)
  if not toml.hasKey("canonical-tests"):
    return

  for uuid, enabled in toml["canonical-tests"].getTable():
    result.add(TrackExerciseTest(uuid: uuid, enabled: enabled.getBool()))

proc newTrackExercise(trackRepoExercise: TrackRepoExercise): TrackExercise =
  if fileExists(trackRepoExercise.testsFile):
    TrackExercise(slug: trackRepoExercise.slug, hasTests: true, tests: parseTrackExerciseTests(trackRepoExercise))
  else:
    TrackExercise(slug: trackRepoExercise.slug, hasTests: false)

proc parseConfigJson(filePath: string): ConfigJson =
  let json = json.parseFile(filePath)
  to(json, ConfigJson)

proc parseExercises(repo: TrackRepo): seq[TrackExercise] =
  let config = parseConfigJson(repo.configFile)
  
  # TODO: refactor this to helper type
  let configExercisesBySlug = config.exercises.mapIt((it.slug, it)).toTable
  let trackRepoExercisesBySlug = repo.exercises.mapIt((it.slug, it)).toTable

  let configExerciseUuids = toSeq(configExercisesBySlug.keys).toHashSet
  let trackRepoExerciseUuids = toSeq(trackRepoExercisesBySlug.keys).toHashSet

  # TODO: Output missing entries
  let validExerciseUuids = configExerciseUuids - trackRepoExerciseUuids

  # TODO: refactor this
  for exerciseUUids in validExerciseUuids:
    result.add(newTrackExercise(trackRepoExercisesBySlug[exerciseUUids]))

proc newTrack(repo: TrackRepo): Track =
  Track(exercises: parseExercises(repo))

proc newTrack*: Track =
  let trackRepo = newTrackRepo()
  trackRepo.newTrack()
