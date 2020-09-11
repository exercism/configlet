import strformat, sequtils, parsetoml, json, os, tables, options, tracks, probspecs

proc syncExerciseData(exercise: TrackExercise, canonicalData: Option[JsonNode]): void =
  echo &"sync exercise {exercise}"

proc syncTests*: void =
  echo "Sync"

  # let probSpecsRepo = newProbSpecsRepo()
  # echo probSpecsRepo.exercises.filterIt(it.slug == "acronym")

  let trackRepo = newTrackRepo()
  echo trackRepo.exercises.filterIt(it.slug == "acronym")

