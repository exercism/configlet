import strformat, os, json, commands, sequtils

type
  ProbSpecsRepo = object
    dir: string
    exerciseDirs: seq[string]

  ProbSpecsTestCase* = object
    uuid*: string
    description*: string
    json*: JsonNode

  ProbSpecsExercise* = object
    slug*: string
    testCases*: seq[ProbSpecsTestCase]

  ProbSpecs* = object
    exercises*: seq[ProbSpecsExercise]

proc newProbSpecsRepo: ProbSpecsRepo =
  let repoDir = joinPath(getCurrentDir(), ".problem-specifications")
  let exerciseDirs = toSeq(walkDirs(joinPath(repoDir, "exercises/*")))
  ProbSpecsRepo(dir: repoDir, exerciseDirs: exerciseDirs)

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

proc parseTestCases(node: JsonNode): seq[ProbSpecsTestCase] =
  if node.hasKey("uuid"):
    result.add(newProbSpecsTestCase(node))
  elif node.hasKey("cases"):
    for childNode in node["cases"].getElems():
      result.add(parseTestCases(childNode))

proc parseTestCases(exerciseDir: string): seq[ProbSpecsTestCase] =
  # TODO: fix Grains JSON parse Error: Parsed integer outside of valid range
  if extractFilename(exerciseDir) == "grains":
    return
  
  let filePath = joinPath(exerciseDir, "canonical-data.json")
  if not fileExists(filePath):
    return
  
  parseTestCases(json.parseFile(filePath))

proc newPropSpecsExercise(exerciseDir: string): ProbSpecsExercise =
  ProbSpecsExercise(slug: extractFilename(exerciseDir), testCases: parseTestCases(exerciseDir))

proc newProbSpecs(repo: ProbSpecsRepo): ProbSpecs =
  ProbSpecs(exercises: repo.exerciseDirs.map(newPropSpecsExercise))

proc newProbSpecs*: ProbSpecs =
  let probSpecsRepo = newProbSpecsRepo()

  # try:
    # probSpecsGitRepo.remove()
    # probSpecsGitRepo.clone()
  probSpecsRepo.newProbSpecs()
  # finally:
  #   probSpecsGitRepo.remove()
