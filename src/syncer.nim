import strformat, sequtils, json, tables, options, tracks, probspecs

proc syncTests* =
  echo "Sync"

  let probSpecsRepo = newProbSpecsRepo()
  let trackRepo = newTrackRepo()

  echo probSpecsRepo.exercises.filterIt(it.slug == "acronym")
  echo trackRepo.exercises.filterIt(it.slug == "acronym")

