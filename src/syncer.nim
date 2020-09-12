import strformat, analyzer

proc syncTests*: void =
  let exercises = findExercises()
  for exercise in exercises:
    echo &"{exercise.slug}: with prob specs"

  # for trackExercise in trackExercises:
  #   let probSpecsExercise = probSpecsExercisesBySlug[trackExercise.slug]
  #   if not probSpecsExercise.hasCanonicalData:
  #     return

  #   if trackExercise.hasTests:
  #     echo &"{trackExercise.slug}: has {trackExercise.tests.len} tests configured of {probSpecsExercise.testCases.len} test cases"
  #   else:
  #     echo &"{trackExercise.slug}: has no tests configured of {probSpecsExercise.testCases.len} test cases"
