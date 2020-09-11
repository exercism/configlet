import strformat, sequtils, json, tables, options, tracks, probspecs

proc syncTests* =
  echo "Sync"

  let probSpecs = newProbSpecs()
  let track = newTrack()

  echo probSpecs.exercises.filterIt(it.slug == "acronym")
  echo track.exercises.filterIt(it.slug == "acronym")

  # echo trackRepo.exercises.mapIt(it.slug)

