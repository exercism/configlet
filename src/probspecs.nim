import strformat, os, json, options, commands, sequtils

type
  ProbSpecsGitRepo = object
    dir: string

  ProbSpecsTestCase* = object
    uuid*: string
    description*: string
    json*: JsonNode

  ProbSpecsCanonicalData* = object
    testCases*: seq[ProbSpecsTestCase]

  ProbSpecsExercise* = object
    slug*: string
    canonicalData*: Option[ProbSpecsCanonicalData]

  ProbSpecsRepo* = object
    exercises*: seq[ProbSpecsExercise]

proc newProbSpecsGitRepo: ProbSpecsGitRepo =
  ProbSpecsGitRepo(dir: joinPath(getCurrentDir(), ".problem-specifications"))

proc clone(gitRepo: ProbSpecsGitRepo): void =
  # TODO: uncomment these lines and remove the other lines once the 'uuids' branch is merged in prob-specs
  # let cmd = &"git clone --depth 1 https://github.com/exercism/problem-specifications.git {gitRepo.dir}"
  # execCmdException(cmd, IOError, "Could not clone problem-specifications repo")
  
  let cmd = &"git clone https://github.com/exercism/problem-specifications.git {gitRepo.dir}"
  execCmdException(cmd, IOError, "Could not clone problem-specifications repo")
  execCmdException("git checkout --track origin/uuids", IOError, "Could not checkout the uuids branch")

proc remove(gitRepo: ProbSpecsGitRepo): void =
  removeDir(gitRepo.dir)

proc newTestCase(json: JsonNode): ProbSpecsTestCase =
  ProbSpecsTestCase(
    uuid: json["uuid"].getStr(),
    description: json["description"].getStr(),
    json: json
  )

proc testCaseJsonNodes(json: JsonNode): seq[JsonNode] =
  if json.hasKey("cases"):
    json["cases"].getElems().map(testCaseJsonNodes).concat
  elif json.hasKey("uuid"):
    @[json]
  else:
    @[]

proc testCasesFromJson(json: JsonNode): seq[ProbSpecsTestCase] =
  testCaseJsonNodes(json).map(newTestCase)

proc tryNewCanonicalData(exerciseDir: string): Option[ProbSpecsCanonicalData] =
  let filePath = joinPath(exerciseDir, "canonical-data.json")

  # TODO: fix Grains JSON parse Error: Parsed integer outside of valid range
  if extractFilename(exerciseDir) == "grains":
    none(ProbSpecsCanonicalData)
  elif fileExists(filePath):
    some(ProbSpecsCanonicalData(testCases: testCasesFromJson(json.parseFile(filePath))))
  else:
    none(ProbSpecsCanonicalData)

proc newExercise(exerciseDir: string): ProbSpecsExercise =
  let slug = extractFilename(exerciseDir)
  let canonicalData = tryNewCanonicalData(exerciseDir)
  ProbSpecsExercise(slug: slug, canonicalData: canonicalData)

proc newProbSpecsRepo(gitRepo: ProbSpecsGitRepo): ProbSpecsRepo =
  let exercisesDir = joinPath(gitRepo.dir, "exercises/*")
  let exercises = toSeq(walkDirs(exercisesDir)).map(newExercise)
  ProbSpecsRepo(exercises: exercises)

proc newProbSpecsRepo*: ProbSpecsRepo =
  let probSpecsGitRepo = newProbSpecsGitRepo()

  # try:
    # probSpecsGitRepo.remove()
    # probSpecsGitRepo.clone()
  probSpecsGitRepo.newProbSpecsRepo()
  # finally:
  #   probSpecsGitRepo.remove()
