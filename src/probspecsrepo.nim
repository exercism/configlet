import strformat, os, json, tables, options, commands, sequtils

type
  ProbSpecsExercise* = object
    slug*: string
    dir*: string
    canonicalDataJsonFile*: string

type ProbSpecsExercisesCanonicalData = Table[string, Option[JsonNode]]

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

proc probSpecExerciseFromDir(dir: string): ProbSpecsExercise =
  ProbSpecsExercise(
    slug: extractFilename(dir),
    dir: dir,
    canonicalDataJsonFile: joinPath(dir, "canonical-data.json"),
  )

proc findProbSpecExercises: seq[ProbSpecsExercise] =
  toSeq(walkDirs(joinPath(probSpecsDir, "exercises/*"))).map(probSpecExerciseFromDir)

proc parseCanonicalData(exercise: ProbSpecsExercise): Option[JsonNode] =
  # TODO: fix JSON parse Error: Parsed integer outside of valid range
  if exercise.slug == "grains":
    return none(JsonNode)

  if fileExists(exercise.canonicalDataJsonFile):
    some(json.parseFile(exercise.canonicalDataJsonFile))
  else:
    none(JsonNode)

proc probSpecsExercisesCanonicalData*: ProbSpecsExercisesCanonicalData =
  toSeq(findProbSpecExercises())
    .mapIt((it.slug, parseCanonicalData(it)))
    .toTable