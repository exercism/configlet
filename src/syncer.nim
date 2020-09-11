import strformat, sequtils, json, tables, options, tracks, probspecs

proc syncTests* =
  let probSpecsExercises = findProbSpecsExercises()
  let trackExercises = findTrackExercises()

  echo "Prob specs"
  echo probSpecsExercises.filterIt(it.slug == "acronym")

  echo "Track"
  echo trackExercises.filterIt(it.slug == "acronym")

  # echo trackRepo.exercises.mapIt(it.slug)

