import strformat, os, json, commands

type
  ProbSpecsRepoExercise = object
    dir: string
    slug: string
    canonicalDataFile: string

  ProbSpecsRepo = object
    dir: string
    exercises: seq[ProbSpecsRepoExercise]

  ProbSpecsTestCase* = object
    uuid*: string
    description*: string
    json*: JsonNode

  ProbSpecsExercise* = object
    slug*: string
    case hasCanonicalData: bool
    of true: 
      testCases*: seq[ProbSpecsTestCase]
    else:
      discard

  ProbSpecs* = object
    exercises*: seq[ProbSpecsExercise]

proc newProbSpecsRepoExercise(dir: string): ProbSpecsRepoExercise =
  ProbSpecsRepoExercise(
    dir: dir,
    slug: extractFilename(dir),
    canonicalDataFile: joinPath(dir, "canonical-data.json"))

proc newProbSpecsRepoExercises(dir: string): seq[ProbSpecsRepoExercise] =
  for exerciseDir in walkDirs(joinPath(dir, "exercises/*")):
    result.add(newProbSpecsRepoExercise(exerciseDir))

proc newProbSpecsRepo: ProbSpecsRepo =
  let dir = joinPath(getCurrentDir(), ".problem-specifications")
  let exercises = newProbSpecsRepoExercises(dir)
  ProbSpecsRepo(dir: dir, exercises: exercises)

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

proc parseProbSpecsTestCases(repoExercise: ProbSpecsRepoExercise): seq[ProbSpecsTestCase] =  
  newProbSpecsTestCases(json.parseFile(repoExercise.canonicalDataFile))

proc newPropSpecsExercise(repoExercise: ProbSpecsRepoExercise): ProbSpecsExercise =
  # TODO: fix Grains JSON parse Error: Parsed integer outside of valid range
  if repoExercise.slug == "grains":
    ProbSpecsExercise(slug: repoExercise.slug, hasCanonicalData: false)
  elif fileExists(repoExercise.canonicalDataFile):
    ProbSpecsExercise(slug: repoExercise.slug, hasCanonicalData: true, testCases: parseProbSpecsTestCases(repoExercise))
  else:
    ProbSpecsExercise(slug: repoExercise.slug, hasCanonicalData: false)

proc newPropSpecsExercises(repo: ProbSpecsRepo): seq[ProbSpecsExercise] =
  for repoExercise in repo.exercises:
    result.add(newPropSpecsExercise(repoExercise))

proc newProbSpecs(repo: ProbSpecsRepo): ProbSpecs =
  ProbSpecs(exercises: newPropSpecsExercises(repo))

proc newProbSpecs*: ProbSpecs =
  let probSpecsRepo = newProbSpecsRepo()

  # try:
    # probSpecsGitRepo.remove()
    # probSpecsGitRepo.clone()
  probSpecsRepo.newProbSpecs()
  # finally:
  #   probSpecsGitRepo.remove()
