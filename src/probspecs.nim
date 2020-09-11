import commands, json, strformat, os

type
  ProbSpecsRepo = object
    dir: string

  ProbSpecsTestCase* = object
    uuid*: string
    description*: string
    json*: JsonNode

  ProbSpecsExerciseKind = enum
    noCanonicalData, withCanonicalData

  ProbSpecsExercise* = object
    slug*: string
    case kind: ProbSpecsExerciseKind
    of withCanonicalData:
      testCases*: seq[ProbSpecsTestCase]
    of noCanonicalData:
      discard

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

proc parseProbSpecsTestCasesFromFile(canonicalDataFile: string): seq[ProbSpecsTestCase] =  
  newProbSpecsTestCases(json.parseFile(canonicalDataFile))

proc newPropSpecsExercise(exerciseDir: string): ProbSpecsExercise =
  let canonicalDataFile = joinPath(exerciseDir, "canonical-data.json")
  let slug = extractFilename(exerciseDir)

  # TODO: fix Grains JSON parse Error: Parsed integer outside of valid range
  if slug == "grains":
    ProbSpecsExercise(slug: slug, kind: noCanonicalData)
  elif fileExists(canonicalDataFile):
    ProbSpecsExercise(slug: slug, kind: withCanonicalData, testCases: parseProbSpecsTestCasesFromFile(canonicalDataFile))
  else:
    ProbSpecsExercise(slug: slug, kind: noCanonicalData)

proc findProbSpecsExercises(repo: ProbSpecsRepo): seq[ProbSpecsExercise] =
  for exerciseDir in walkDirs(joinPath(repo.dir, "exercises/*")):
    result.add(newPropSpecsExercise(exerciseDir))

proc findProbSpecsExercises*: seq[ProbSpecsExercise] =
  let probSpecsRepo = newProbSpecsRepo()

  # try:
    # probSpecsRepo.remove()
    # probSpecsRepo.clone()
  probSpecsRepo.findProbSpecsExercises()
  # finally:
  #   probSpecsRepo.remove()
