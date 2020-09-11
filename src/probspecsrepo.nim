import strformat, os, json, tables, options, commands, sequtils

type
  ProbSpecsExerciseCanonicalData* = object
    json*: JsonNode

type
  ProbSpecsExercise* = object
    slug*: string
    canonicalData*: Option[ProbSpecsExerciseCanonicalData]

type
  ProbSpecsExercises* = object
    exercises*: seq[ProbSpecsExercise]

let probSpecsDir = joinPath(getCurrentDir(), ".problem-specifications")

proc cloneProbSpecsRepo*: void =
  # TODO: uncomment these lines and remove the other lines once the 'uuids' branch is merged in prob-specs
  # let cmd = &"git clone --depth 1 https://github.com/exercism/problem-specifications.git {probSpecsDir}"
  # execCmdException(cmd, IOError, "Could not clone problem-specifications repo")
  
  let cmd = &"git clone https://github.com/exercism/problem-specifications.git {probSpecsDir}"
  execCmdException(cmd, IOError, "Could not clone problem-specifications repo")
  execCmdException("git checkout --track origin/uuids", IOError, "Could not checkout the uuids branch")

proc removeProbSpecsRepo*: void =
  removeDir(probSpecsDir)

proc probSpecsExerciseCanonicalDataFromDir(dir: string): Option[ProbSpecsExerciseCanonicalData] =
  let filePath = joinPath(dir, "canonical-data")

  # TODO: fix JSON parse Error: Parsed integer outside of valid range
  # if exercise.slug == "grains":
  #   return none(ProbSpecsExerciseCanonicalData)
    
  if fileExists(filePath):
    some(ProbSpecsExerciseCanonicalData(json: json.parseFile(filePath)))
  else:
    none(ProbSpecsExerciseCanonicalData)

proc probSpecExerciseFromDir(dir: string): ProbSpecsExercise =
  ProbSpecsExercise(
    slug: extractFilename(dir),
    canonicalData: probSpecsExerciseCanonicalDataFromDir(dir)
  )

proc findProbSpecExercises: ProbSpecsExercises =
  let exercisesDir = joinPath(probSpecsDir, "exercises/*")
  let exercises = toSeq(walkDirs(exercisesDir)).map(probSpecExerciseFromDir)
  ProbSpecsExercises(exercises: exercises)
