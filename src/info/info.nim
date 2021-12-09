import std/[algorithm, os, strscans, sequtils, sets, strformat, strutils,
            terminal]
import ".."/[cli, lint/track_config]

type
  ProbSpecsExercises = object
    withCanonicalData: HashSet[string]
    noCanonicalData: HashSet[string]
    deprecated: HashSet[string]

proc getPsExercises(path: static string): ProbSpecsExercises =
  ## Reads the slugs file at `path` at compile-time, and returns an object
  ## containing every exercise in `exercism/problem-specifications`, grouped by
  ## kind.
  let contents = staticRead(path)
  var header: string
  result = ProbSpecsExercises()
  for line in contents.splitLines():
    if line.len > 0:
      if line[0] != '#':
        if line.scanf("[$+]$.", header):
          discard
        else:
          case header
          of "with-canonical-data":
            result.withCanonicalData.incl line
          of "no-canonical-data":
            result.noCanonicalData.incl line
          of "deprecated":
            result.deprecated.incl line
          else:
            doAssert false

proc getProbSpecsSlugs: HashSet[string] =
  # TODO: automatically update this at build-time?
  const slugsPath = currentSourcePath().parentDir() / "prob_specs_slugs.txt"
  let psExercises = getPsExercises(slugsPath)
  result = psExercises.withCanonicalData + psExercises.noCanonicalData

func getConceptSlugs(concepts: Concepts): HashSet[string] =
  ## Returns the `slug` of every concept in `concepts`.
  result = initHashSet[string](concepts.len)
  for item in concepts:
    result.incl item.slug

func getPrereqs(practiceExercises: seq[PracticeExercise]): HashSet[string] =
  ## Returns the concepts that appear at least once in the `prerequisites` array
  ## of a Practice Exercise in `practiceExercises`.
  result = initHashSet[string]()
  for practiceExercise in practiceExercises:
    for prereq in practiceExercise.prerequisites:
      result.incl prereq

func getPractices(practiceExercises: seq[PracticeExercise]): HashSet[string] =
  ## Returns the concepts that appear at least once in the `practices` array
  ## of a Practice Exercise in `practiceExercises`.
  result = initHashSet[string]()
  for practiceExercise in practiceExercises:
    for item in practiceExercise.practices:
      result.incl item

proc header(s: string): string =
  if colorStdout:
    const ansi = ansiForegroundColorCode(fgBlue)
    &"{ansi}{s}{ansiResetCode}\n"
  else:
    &"{s}\n"

proc show[A](s: SomeSet[A], header: string): string =
  ## Returns a string containing a colorized (when appropriate) `header`, and
  ## then the elements of `s` in alphabetical order
  result = header(header)
  if s.len > 0:
    var elements = toSeq(s)
    sort elements
    for item in elements:
      result.add item
      result.add "\n"
  else:
    result.add "none\n"
  result.add "\n"

proc conceptsInfo(practiceExercises: seq[PracticeExercise],
                  concepts: seq[Concept]): string =
  let conceptSlugs = getConceptSlugs(concepts)
  let prereqs = getPrereqs(practiceExercises)
  let practices = getPractices(practiceExercises)

  let conceptsThatArentAPrereq = conceptSlugs - prereqs
  result = show(conceptsThatArentAPrereq,
      "Concepts that aren't a prerequisite for any Practice Exercise:")

  let conceptsThatArentPracticed = conceptSlugs - practices
  result.add show(conceptsThatArentPracticed,
      "Concepts that aren't practiced by any Practice Exercise:")

  let conceptsThatAreAPrereqButArentPracticed = prereqs - practices
  result.add show(conceptsThatAreAPrereqButArentPracticed,
      "Concepts that are a prerequisite, but aren't practiced by any Practice Exercise:")
  stripLineEnd(result)

func getSlugs(practiceExercises: seq[PracticeExercise]): HashSet[string] =
  result = initHashSet[string](practiceExercises.len)
  for practiceExercise in practiceExercises:
    result.incl practiceExercise.slug

proc unimplementedProbSpecsExercises(practiceExercises: seq[PracticeExercise],
                                     foregone: HashSet[string],
                                     probSpecsSlugs: HashSet[string]): string =
  let practiceExerciseSlugs = getSlugs(practiceExercises)
  let unimplementedProbSpecsSlugs = probSpecsSlugs - practiceExerciseSlugs - foregone
  result = show(unimplementedProbSpecsSlugs,
      &"There are {unimplementedProbSpecsSlugs.len} exercises from " &
       "`exercism/problem-specifications` that are neither implemented, nor " &
       "deprecated upstream, nor in the track config " &
       "`exercises.foregone` array:")
  stripLineEnd(result)

func count(exercises: seq[ConceptExercise] |
                      seq[PracticeExercise]): tuple[visible: int, wip: int] =
  result = (0, 0)
  for exercise in exercises:
    case exercise.status
    of sMissing, sBeta, sActive:
      inc result.visible
    of sWip:
      inc result.wip
    of sDeprecated:
      discard

proc trackSummary(conceptExercises: seq[ConceptExercise],
                  practiceExercises: seq[PracticeExercise],
                  concepts: seq[Concept]): string =
  let (numConceptExercises, numConceptExercisesWip) = count(conceptExercises)
  let (numPracticeExercises, numPracticeExercisesWip) = count(practiceExercises)
  let numExercises = numConceptExercises + numPracticeExercises
  let numExercisesWip = numConceptExercisesWip + numPracticeExercisesWip
  let numConcepts = concepts.len
  result = header("Track summary:")
  result.add fmt"""
    {numConceptExercises:>3} Concept Exercises (plus {numConceptExercisesWip} work-in-progress)
    {numPracticeExercises:>3} Practice Exercises (plus {numPracticeExercisesWip} work-in-progress)
    {numExercises:>3} Exercises in total (plus {numExercisesWip} work-in-progress)
    {numConcepts:>3} Concepts""".unindent(4)

proc info*(conf: Conf) =
  let trackConfigPath = conf.trackDir / "config.json"

  if fileExists(trackConfigPath):
    let trackConfigContents = readFile(trackConfigPath)
    let trackConfig = TrackConfig.init(trackConfigContents)

    let exercises = trackConfig.exercises
    let conceptExercises = exercises.`concept`
    let practiceExercises = exercises.practice
    let foregone = exercises.foregone
    let concepts = trackConfig.concepts

    echo conceptsInfo(practiceExercises, concepts)
    const probSpecsSlugs = getProbSpecsSlugs()
    echo unimplementedProbSpecsExercises(practiceExercises, foregone, probSpecsSlugs)
    echo trackSummary(conceptExercises, practiceExercises, concepts)
  else:
    var msg = &"file does not exist: {trackConfigPath}"
    if conf.trackDir == getCurrentDir():
      msg.add "\nBy default, configlet looks for the track config.json file " &
              "in the current directory.\n" &
              "To specify a different directory, use this option: --track-dir <dir>"
    showError(msg)
