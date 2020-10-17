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
  logDetailed(&"Cloning the problem-specifications repo into {repo.dir}...")
  execCmdException(cmd, "Could not clone problem-specifications repo")

proc grainsWorkaround(repo: ProbSpecsRepo) =
  ## Overwrites the canonical data file for `grains` so that it no longer
  ## contains integers that are too large to store in a 64-bit signed integer.
  ## Otherwise, we get an error when parsing it as JSON.
  let grainsPath = repo.dir / "exercises" / "grains" / "canonical-data.json"
  let s = readFile(grainsPath).multiReplace(
    ("92233720368547758", "92233720368547758.0"),
    ("184467440737095516", "184467440737095516.0"))
  writeFile(grainsPath, s)

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
  initProbSpecsTestCases(json.parseFile(repoExercise.canonicalDataFile))

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
    probSpecsRepo.grainsWorkaround()
    probSpecsRepo.findProbSpecsExercises(conf)
  finally:
    probSpecsRepo.remove()
