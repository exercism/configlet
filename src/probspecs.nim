import std/[json, options, os, osproc, sequtils, strformat]
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
  getCurrentDir() / ".problem-specifications"

proc initProbSpecsRepo: ProbSpecsRepo =
  result.dir = probSpecsDir()

proc clone(repo: ProbSpecsRepo): void =
  let cmd = &"git clone --depth 1 https://github.com/exercism/problem-specifications.git {repo.dir}"
  execCmdException(cmd, "Could not clone problem-specifications repo")

proc remove(repo: ProbSpecsRepo): void =
  removeDir(repo.dir)

proc initProbSpecsRepoExercise(dir: string): ProbSpecsRepoExercise =
  result.dir = dir

proc exercisesDir(repo: ProbSpecsRepo): string =
  repo.dir / "exercises"

proc exercises(repo: ProbSpecsRepo): seq[ProbSpecsRepoExercise] =
  for exerciseDir in walkDirs(repo.exercisesDir / "*"):
    result.add(initProbSpecsRepoExercise(exerciseDir))

proc canonicalDataFile(repoExercise: ProbSpecsRepoExercise): string =
  repoExercise.dir / "canonical-data.json"

proc hasCanonicalDataFile(repoExercise: ProbSpecsRepoExercise): bool =
  fileExists(repoExercise.canonicalDataFile())

proc exercisesWithCanonicalData(repo: ProbSpecsRepo): seq[ProbSpecsRepoExercise] =
  for repoExercise in repo.exercises().filter(hasCanonicalDataFile):
    result.add(repoExercise)

proc slug(repoExercise: ProbSpecsRepoExercise): string =
  extractFilename(repoExercise.dir)

proc initProbSpecsTestCase(node: JsonNode): ProbSpecsTestCase =
  result.json = node

proc uuid*(testCase: ProbSpecsTestCase): string =
  testCase.json["uuid"].getStr()

proc description*(testCase: ProbSpecsTestCase): string =
  testCase.json["description"].getStr()

proc reimplementation*(testCase: ProbSpecsTestCase): bool =
  testCase.json.hasKey("reimplements")

proc reimplements*(testCase: ProbSpecsTestCase): string =
  testCase.json["reimplements"].getStr()

proc initProbSpecsTestCases(node: JsonNode): seq[ProbSpecsTestCase] =
  if node.hasKey("uuid"):
    result.add(initProbSpecsTestCase(node))
  elif node.hasKey("cases"):
    for childNode in node["cases"].getElems():
      result.add(initProbSpecsTestCases(childNode))

proc parseProbSpecsTestCases(repoExercise: ProbSpecsRepoExercise): seq[ProbSpecsTestCase] =
  if repoExercise.slug == "grains":
    return

  initProbSpecsTestCases(json.parseFile(repoExercise.canonicalDataFile))

proc initPropSpecsExercise(repoExercise: ProbSpecsRepoExercise): ProbSpecsExercise =
  result.slug = repoExercise.slug
  result.testCases = parseProbSpecsTestCases(repoExercise)

proc findProbSpecsExercises(repo: ProbSpecsRepo, args: Arguments): seq[ProbSpecsExercise] =
  for repoExercise in repo.exercisesWithCanonicalData():
    if args.exercise.isNone or args.exercise.get() == repoExercise.slug:
      result.add(initPropSpecsExercise(repoExercise))

proc findProbSpecsExercises*(args: Arguments): seq[ProbSpecsExercise] =
  let probSpecsRepo = initProbSpecsRepo()

  try:
    probSpecsRepo.remove()
    probSpecsRepo.clone()
    probSpecsRepo.findProbSpecsExercises(args)
  finally:
    probSpecsRepo.remove()
