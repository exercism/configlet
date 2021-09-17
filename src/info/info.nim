import std/[algorithm, os, sets, terminal]
import ".."/[cli, lint/track_config]

proc getConceptSlugs(concepts: Concepts): HashSet[string] =
  ## Returns the slug of every concept.
  for item in concepts:
    result.incl item.slug

proc getPrereqs(practiceExercises: seq[PracticeExercise]): HashSet[string] =
  ## Returns the deduplicated values of every practice exercise `prerequisites` key.
  for practiceExercise in practiceExercises:
    for prereq in practiceExercise.prerequisites:
      result.incl prereq

proc getPractices(practiceExercises: seq[PracticeExercise]): HashSet[string] =
  ## Returns the deduplicated values of every practice exercise `practices` key.
  for practiceExercise in practiceExercises:
    for item in practiceExercise.practices:
      result.incl item

proc echoHeader(s: string) =
  stdout.styledWriteLine(fgBlue, s)

proc show(s: HashSet[string], header: string) =
  ## Prints `header` and then the elements of `s` in alphabetical order
  echoHeader(header)
  if s.len > 0:
    var elements = newSeq[string](s.len)
    var i = 0
    for item in s:
      elements[i] = item
      inc i
    sort elements
    for item in elements:
      echo item
  else:
    echo "none"
  echo ""

proc concepts(trackConfig: TrackConfig) =
  let exercises = trackConfig.exercises
  let practiceExercises = exercises.practice
  let concepts = trackConfig.concepts

  let conceptSlugs = getConceptSlugs(concepts)

  let prereqs = getPrereqs(practiceExercises)
  let conceptsThatArentAPrereq = conceptSlugs - prereqs
  show(conceptsThatArentAPrereq,
       "Concepts that aren't a prerequisite for any practice exercise:")

  let practices = getPractices(practiceExercises)
  let conceptsThatArentPracticed = conceptSlugs - practices
  show(conceptsThatArentPracticed,
       "Concepts that aren't practiced by any practice exercise:")

  let conceptsThatAreAPrereqButArentPracticed = prereqs - practices
  show(conceptsThatAreAPrereqButArentPracticed,
       "Concepts that are a prerequisite, but aren't practiced by any practice exercise:")

proc info*(conf: Conf) =
  let trackConfigContents = readFile(conf.trackDir / "config.json")
  let trackConfig = TrackConfig.init(trackConfigContents)
  concepts(trackConfig)
