import json, sequtils, strformat, os, osproc

type
  ProbSpecsRepo = object
    dir: string

  ProbSpecsTestCase* = object
    uuid*: string
    description*: string
    json*: JsonNode

  ProbSpecsExercise* = object
    slug*: string
    testCases*: seq[ProbSpecsTestCase]

proc execCmdException*(cmd: string, exceptn: typedesc, message: string): void =
  if execCmd(cmd) != 0:
    raise newException(exceptn, message)

proc newProbSpecsRepo: ProbSpecsRepo =
  let dir = joinPath(getCurrentDir(), ".problem-specifications")
  ProbSpecsRepo(dir: dir)

proc clone(repo: ProbSpecsRepo): void =
  # TODO: uncomment these lines and remove the other lines once the 'uuids' branch is merged in prob-specs
  # let cmd = &"git clone --depth 1 https://github.com/exercism/problem-specifications.git {repo.dir}"
  # execCmdException(cmd, IOError, "Could not clone problem-specifications repo")
  
  let cmd = &"git clone https://github.com/exercism/problem-specifications.git {repo.dir}"
  execCmdException(cmd, IOError, "Could not clone problem-specifications repo")
  execCmdException("git checkout --track origin/uuids", IOError, "Could not checkout the uuids branch")

proc remove(repo: ProbSpecsRepo): void =
  removeDir(repo.dir)

proc newProbSpecsTestCase(node: JsonNode): ProbSpecsTestCase =
  ProbSpecsTestCase(
    uuid: node["uuid"].getStr(),
    description: node["description"].getStr(),
    json: node
  )

proc newProbSpecsTestCases(node: JsonNode): seq[ProbSpecsTestCase] =
  if node.hasKey("uuid"):
    result.add(newProbSpecsTestCase(node))
  elif node.hasKey("cases"):
    for childNode in node["cases"].getElems():
      result.add(newProbSpecsTestCases(childNode))

proc slugFromDir(exerciseDir: string): string =
  extractFilename(exerciseDir)

proc canonicalDataFile(exerciseDir: string): string =
  joinPath(exerciseDir, "canonical-data.json")

proc parseProbSpecsTestCasesFromFile(exerciseDir: string): seq[ProbSpecsTestCase] =  
  if slugFromDir(exerciseDir) == "grains":
    @[]
  else:  
    newProbSpecsTestCases(json.parseFile(canonicalDataFile(exerciseDir)))

proc hasCanonicalDataFile(exerciseDir: string): bool =
  fileExists(canonicalDataFile(exerciseDir))

proc exerciseDirs(repo: ProbSpecsRepo): seq[string] =
  for exerciseDir in walkDirs(joinPath(repo.dir, "exercises/*")):
    result.add(exerciseDir)

proc newPropSpecsExercise(exerciseDir: string): ProbSpecsExercise =
  ProbSpecsExercise(slug: slugFromDir(exerciseDir), testCases: parseProbSpecsTestCasesFromFile(exerciseDir))

proc findProbSpecsExercises(repo: ProbSpecsRepo): seq[ProbSpecsExercise] =
  for exerciseDir in exerciseDirs(repo).filter(hasCanonicalDataFile):
    result.add(newPropSpecsExercise(exerciseDir))

proc findProbSpecsExercises*: seq[ProbSpecsExercise] =
  let probSpecsRepo = newProbSpecsRepo()

  # try:
    # probSpecsRepo.remove()
    # probSpecsRepo.clone()
  probSpecsRepo.findProbSpecsExercises()
  # finally:
  #   probSpecsRepo.remove()
