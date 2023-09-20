import std/[algorithm, os, sequtils, sets, strformat, strutils, sugar, terminal]
import pkg/jsony
import ".."/[cli, sync/probspecs, types_track_config]

proc header(s: string): string =
  if colorStdout:
    const ansi = ansiForegroundColorCode(fgBlue)
    &"{ansi}{s}{ansiResetCode}\n"
  else:
    &"{s}\n"

func toStringSorted(x: HashSet[string]): string =
  var elements = toSeq(x)
  sort elements
  result = elements.join("\n")
  result.add '\n'

proc show(x: HashSet[string], header: string): string =
  ## Returns a string containing a colorized (when appropriate) `header`, and
  ## then the elements of `x` in alphabetical order
  result = header(header)
  if x.len > 0:
    result.add toStringSorted(x)
  else:
    result.add "none\n"
  result.add "\n"

proc conceptsInfo(practiceExercises: seq[PracticeExercise],
                  concepts: seq[Concept]): string =
  let
    conceptSlugs = collect:
      for con in concepts:
        {con.slug}

    prereqs = collect:
      for p in practiceExercises:
        for prereq in p.prerequisites:
          {prereq}

    practices = collect:
      for p in practiceExercises:
        for prac in p.practices:
          {prac}

    conceptsThatArentAPrereq = conceptSlugs - prereqs
    conceptsThatArentPracticed = conceptSlugs - practices
    conceptsThatAreAPrereqButArentPracticed = prereqs - practices

  result = show(conceptsThatArentAPrereq,
      "Concepts that aren't a prerequisite for any Practice Exercise:")
  result.add show(conceptsThatArentPracticed,
      "Concepts that aren't practiced by any Practice Exercise:")
  result.add show(conceptsThatAreAPrereqButArentPracticed,
      "Concepts that are a prerequisite, but aren't practiced by any Practice Exercise:")
  stripLineEnd(result)

type
  ProbSpecsExercises = object
    withCanonicalData: HashSet[string]
    withoutCanonicalData: HashSet[string]
    deprecated: HashSet[string]

proc init(T: typedesc[ProbSpecsExercises], probSpecsDir: ProbSpecsDir): T =
  result = T()
  for kind, path in walkDir(probSpecsDir / "exercises"):
    if kind == pcDir:
      let exerciseSlug = path.lastPathPart()
      if fileExists(path / ".deprecated"):
        result.deprecated.incl exerciseSlug
      elif fileExists(path / "canonical-data.json"):
        result.withCanonicalData.incl exerciseSlug
      else:
        result.withoutCanonicalData.incl exerciseSlug

proc unimplementedProbSpecsExercises(practiceExercises: seq[PracticeExercise],
                                     foregone: OrderedSet[string],
                                     probSpecsDir: ProbSpecsDir): string =
  let
    probSpecsExercises = ProbSpecsExercises.init(probSpecsDir)
    practiceExerciseSlugs = collect:
      for p in practiceExercises:
        {p.slug.`$`}
    uWith = probSpecsExercises.withCanonicalData - practiceExerciseSlugs -
        foregone.toSeq.toHashSet
    uWithout = probSpecsExercises.withoutCanonicalData - practiceExerciseSlugs -
        foregone.toSeq.toHashSet
    header =
      &"There are {uWith.len + uWithout.len} non-deprecated exercises " &
      "in `exercism/problem-specifications` that\n" &
      "are both unimplemented and not in the track config `exercises.foregone` array:"

  result = header(header)
  if uWith.len > 0 or uWithout.len > 0:
    for (u, s) in [(uWith, "With"), (uWithout, "Without")]:
      if u.len > 0:
        result.add &"\n{s} canonical data:\n"
        result.add toStringSorted(u)
  else:
    result.add "none\n"

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
  let
    (numConceptExercises, numConceptExercisesWip) = count(conceptExercises)
    (numPracticeExercises, numPracticeExercisesWip) = count(practiceExercises)
    numExercises = numConceptExercises + numPracticeExercises
    numExercisesWip = numConceptExercisesWip + numPracticeExercisesWip
    numConcepts = concepts.len

  result = header("Track summary:")
  result.add fmt"""
    {numConceptExercises:>3} Concept Exercises (plus {numConceptExercisesWip} work-in-progress)
    {numPracticeExercises:>3} Practice Exercises (plus {numPracticeExercisesWip} work-in-progress)
    {numExercises:>3} Exercises in total (plus {numExercisesWip} work-in-progress)
    {numConcepts:>3} Concepts""".unindent(4) # Preserve right-alignment of digits.

proc info*(conf: Conf) =
  let trackConfigPath = conf.trackDir / "config.json"

  if fileExists(trackConfigPath):
    let t = TrackConfig.init trackConfigPath.readFile()
    let probSpecsDir = ProbSpecsDir.init(conf)
    echo conceptsInfo(t.exercises.practice, t.concepts)
    echo unimplementedProbSpecsExercises(t.exercises.practice, t.exercises.foregone,
                                         probSpecsDir)
    echo trackSummary(t.exercises.`concept`, t.exercises.practice, t.concepts)
  else:
    var msg = &"file does not exist: {trackConfigPath}"
    if conf.trackDir == getCurrentDir():
      msg.add "\nBy default, configlet looks for the track config.json file " &
              "in the current directory.\n" &
              "To specify a different directory, use this option: --track-dir <dir>"
    showError(msg)
