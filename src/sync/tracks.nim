import std/[json, os, sets]
import pkg/parsetoml
import ".."/cli

type
  ConfigJsonExercise = distinct string

  TrackDir = distinct string

  TrackRepoExercise = distinct string

  TrackExerciseTests* = object
    included*: HashSet[string]
    excluded*: HashSet[string]

  TrackExercise* = object
    slug*: string
    tests*: TrackExerciseTests
    repoExercise: TrackRepoExercise

proc `/`(head: TrackDir, tail: string): string {.borrow.}
proc `/`(head: TrackRepoExercise, tail: string): string {.borrow.}
proc `/`(head: string, tail: ConfigJsonExercise): string {.borrow.}
proc extractFilename(exercise: TrackRepoExercise): string {.borrow.}

func slug(exercise: TrackRepoExercise): string =
  extractFilename(exercise)

func testsFile(exercise: TrackRepoExercise): string =
  exercise / ".meta" / "tests.toml"

func testsFile*(exercise: TrackExercise): string =
  exercise.repoExercise.testsFile()

func initTrackRepoExercise(trackDir: TrackDir,
    exercise: ConfigJsonExercise): TrackRepoExercise =
  TrackRepoExercise(trackDir / "exercises" / "practice" / exercise)

proc exercises(trackDir: TrackDir): seq[TrackRepoExercise] =
  let config = json.parseFile(trackDir / "config.json")["exercises"]

  if config.hasKey("practice"):
    let practiceExercises = config["practice"]
    result = newSeqOfCap[TrackRepoExercise](practiceExercises.len)

    for exercise in practiceExercises:
      if exercise.hasKey("slug"):
        if exercise["slug"].kind == JString:
          let configJsonExercise = ConfigJsonExercise(exercise["slug"].getStr())
          result.add initTrackRepoExercise(trackDir, configJsonExercise)

proc initTrackExerciseTests(exercise: TrackRepoExercise): TrackExerciseTests =
  let testsFile = testsFile(exercise)
  if fileExists(testsFile):
    let tests = parsetoml.parseFile(testsFile)

    for uuid, val in tests.getTable():
      if val.hasKey("include"):
        if val["include"].kind == Bool:
          let isIncluded = val["include"].getBool()
          if isIncluded:
            result.included.incl(uuid)
          else:
            result.excluded.incl(uuid)
        else:
          let msg = "Error: the value of an `include` key is `" &
                    val["include"].toTomlString() & "`, but it must be a bool:\n" &
                    exercise.testsFile()
          stderr.writeLine(msg)
      else:
        result.included.incl(uuid)

proc initTrackExercise(exercise: TrackRepoExercise): TrackExercise =
  TrackExercise(
    slug: slug(exercise),
    tests: initTrackExerciseTests(exercise),
  )

proc findTrackExercises(trackDir: TrackDir, conf: Conf): seq[TrackExercise] =
  let repoExercises = exercises(trackDir)
  result = newSeqOfCap[TrackExercise](repoExercises.len)

  for repoExercise in repoExercises:
    if conf.action.exercise.len == 0 or conf.action.exercise == slug(repoExercise):
      result.add initTrackExercise(repoExercise)

proc findTrackExercises*(conf: Conf): seq[TrackExercise] =
  let trackDir = TrackDir(conf.trackDir)
  trackDir.findTrackExercises(conf)
