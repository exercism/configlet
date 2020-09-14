import json, sequtils, strformat, options, os, osproc
import arguments

type
  ProbSpecsRepoExercise = object
    dir: string

  ProbSpecsRepo = object
    dir: string

  ProbSpecsTestCase* = object
    json*: JsonNode

  ProbSpecsExercise* = object
    slug*: string
    testCases*: seq[ProbSpecsTestCase]

proc execCmdException*(cmd: string, message: string): void =
  if execCmd(cmd) != 0:
    quit(message)

proc probSpecsDir: string =
  joinPath(getCurrentDir(), ".problem-specifications")

proc newProbSpecsRepo: ProbSpecsRepo =
  result.dir = probSpecsDir()

proc clone(repo: ProbSpecsRepo): void =
  # TODO: uncomment these lines and remove the other lines once the 'uuids' branch is merged in prob-specs
  # let cmd = &"git clone --depth 1 https://github.com/exercism/problem-specifications.git {repo.dir}"
  # execCmdException(cmd, "Could not clone problem-specifications repo")
  
  let cmd = &"git clone https://github.com/exercism/problem-specifications.git {repo.dir}"
  execCmdException(cmd, "Could not clone problem-specifications repo")
  execCmdException("git checkout --track origin/uuids", "Could not checkout the uuids branch")

proc remove(repo: ProbSpecsRepo): void =
  removeDir(repo.dir)

proc newProbSpecsRepoExercise(dir: string): ProbSpecsRepoExercise =
  result.dir = dir

proc exercisesDir(repo: ProbSpecsRepo): string =
  joinPath(repo.dir, "exercises")

proc exercises(repo: ProbSpecsRepo): seq[ProbSpecsRepoExercise] =
  for exerciseDir in walkDirs(joinPath(repo.exercisesDir, "*")):
    result.add(newProbSpecsRepoExercise(exerciseDir))

proc canonicalDataFile(repoExercise: ProbSpecsRepoExercise): string =
  joinPath(repoExercise.dir, "canonical-data.json")

proc hasCanonicalDataFile(repoExercise: ProbSpecsRepoExercise): bool =
  fileExists(repoExercise.canonicalDataFile())

proc exercisesWithCanonicalData(repo: ProbSpecsRepo): seq[ProbSpecsRepoExercise] =
  for repoExercise in repo.exercises().filter(hasCanonicalDataFile):
    result.add(repoExercise)

proc slug(repoExercise: ProbSpecsRepoExercise): string =
  extractFilename(repoExercise.dir)

proc newProbSpecsTestCase(node: JsonNode): ProbSpecsTestCase =
  result.json = node

proc uuid*(testCase: ProbSpecsTestCase): string =
  testCase.json["uuid"].getStr()

proc description*(testCase: ProbSpecsTestCase): string =
  testCase.json["description"].getStr()

proc newProbSpecsTestCases(node: JsonNode): seq[ProbSpecsTestCase] =
  if node.hasKey("uuid"):
    result.add(newProbSpecsTestCase(node))
  elif node.hasKey("cases"):
    for childNode in node["cases"].getElems():
      result.add(newProbSpecsTestCases(childNode))

proc parseProbSpecsTestCases(repoExercise: ProbSpecsRepoExercise): seq[ProbSpecsTestCase] =  
  if repoExercise.slug == "grains":
    return

  newProbSpecsTestCases(json.parseFile(repoExercise.canonicalDataFile))

proc newPropSpecsExercise(repoExercise: ProbSpecsRepoExercise): ProbSpecsExercise =
  result.slug = repoExercise.slug
  result.testCases = parseProbSpecsTestCases(repoExercise)

proc findProbSpecsExercises(repo: ProbSpecsRepo, args: Arguments): seq[ProbSpecsExercise] =
  for repoExercise in repo.exercisesWithCanonicalData():
    if args.exercise.isNone or args.exercise.get() == repoExercise.slug:
      result.add(newPropSpecsExercise(repoExercise))

proc findProbSpecsExercises*(args: Arguments): seq[ProbSpecsExercise] =
  let probSpecsRepo = newProbSpecsRepo()

  # TODO: enable checking prob-specs repo
  # try:
    # probSpecsRepo.remove()
    # probSpecsRepo.clone()
  probSpecsRepo.findProbSpecsExercises(args)
  # finally:
  #   probSpecsRepo.remove()
