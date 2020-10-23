import std/[json, options, os, osproc, sequtils, strformat, strutils]
import cli, logger

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

proc execCmdException*(cmd: string, message: string) =
  if execCmd(cmd) != 0:
    quit(message)

proc probSpecsDir: string =
  getCurrentDir() / ".problem-specifications"

proc initProbSpecsRepo: ProbSpecsRepo =
  result.dir = probSpecsDir()

proc clone(repo: ProbSpecsRepo) =
  let cmd = &"git clone --quiet --depth 1 https://github.com/exercism/problem-specifications.git {repo.dir}"
  logNormal(&"Cloning the problem-specifications repo into {repo.dir}...")
  execCmdException(cmd, "Could not clone problem-specifications repo")

proc remove(repo: ProbSpecsRepo) =
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

proc isReimplementation*(testCase: ProbSpecsTestCase): bool =
  testCase.json.hasKey("reimplements")

proc reimplements*(testCase: ProbSpecsTestCase): string =
  testCase.json["reimplements"].getStr()

proc initProbSpecsTestCases(node: JsonNode): seq[ProbSpecsTestCase] =
  if node.hasKey("uuid"):
    result.add(initProbSpecsTestCase(node))
  elif node.hasKey("cases"):
    for childNode in node["cases"].getElems():
      result.add(initProbSpecsTestCases(childNode))

proc grainsWorkaround(grainsPath: string): JsonNode =
  ## Parses the canonical data file for `grains`, replacing the too-large
  ## integers with floats. This avoids an error that otherwise occurs when
  ## parsing integers are too large to store as a 64-bit signed integer.
  let sanitised = readFile(grainsPath).multiReplace(
    ("92233720368547758", "92233720368547758.0"),
    ("184467440737095516", "184467440737095516.0"))
  result = parseJson(sanitised)

proc parseProbSpecsTestCases(repoExercise: ProbSpecsRepoExercise): seq[ProbSpecsTestCase] =
  if repoExercise.slug == "grains":
    repoExercise.canonicalDataFile().grainsWorkaround().initProbSpecsTestCases()
  else:
    repoExercise.canonicalDataFile().parseFile().initProbSpecsTestCases()

proc initProbSpecsExercise(repoExercise: ProbSpecsRepoExercise): ProbSpecsExercise =
  result.slug = repoExercise.slug
  result.testCases = parseProbSpecsTestCases(repoExercise)

proc findProbSpecsExercises(repo: ProbSpecsRepo, conf: Conf): seq[ProbSpecsExercise] =
  for repoExercise in repo.exercisesWithCanonicalData():
    if conf.exercise.isNone or conf.exercise.get() == repoExercise.slug:
      result.add(initProbSpecsExercise(repoExercise))

proc findProbSpecsExercises*(conf: Conf): seq[ProbSpecsExercise] =
  let probSpecsRepo = initProbSpecsRepo()

  try:
    probSpecsRepo.remove()
    probSpecsRepo.clone()
    probSpecsRepo.findProbSpecsExercises(conf)
  finally:
    probSpecsRepo.remove()
