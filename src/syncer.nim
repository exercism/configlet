import strformat, sequtils, json, tables, options, tracks, probspecs

proc syncTests* =
  let probSpecsExercises = findProbSpecsExercises()
  let probSpecsExercisesBySlug = probSpecsExercises.mapIt((it.slug, it)).toTable
  let trackExercises = findTrackExercises()

  for trackExercise in trackExercises:
    let probSpecsExercise = probSpecsExercisesBySlug[trackExercise.slug]
    if not probSpecsExercise.hasCanonicalData:
      return

    if trackExercise.hasTests:
      echo &"{trackExercise.slug}: has {trackExercise.tests.len} tests configured of {probSpecsExercise.testCases.len} test cases"
    else:
      echo &"{trackExercise.slug}: has no tests configured of {probSpecsExercise.testCases.len} test cases"
