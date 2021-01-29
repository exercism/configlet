import std/[json, os, osproc, sequtils, strformat, strscans, strutils]
import ".."/[cli, helpers, logger]

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
    if conf.action.exercise.len == 0 or conf.action.exercise == repoExercise.slug:
      result.add(initProbSpecsExercise(repoExercise))

proc getNameOfRemote(probSpecsDir, host, location: string): string =
  ## Returns the name of the remote in `probSpecsDir` that points to `location`
  ## at `host`.
  ##
  ## Exits with an error if there is no such remote.
  # There's probably a better way to do this than parsing `git remote -v`.
  let (remotes, errRemotes) = execCmdEx("git remote -v")
  if errRemotes != 0:
    showError("could not run `git remote -v` in the given " &
              &"problem-specifications directory: '{probSpecsDir}'")
  var remoteName, remoteUrl: string
  for line in remotes.splitLines():
    discard line.scanf("$s$w$s$+fetch)$.", remoteName, remoteUrl)
    if remoteUrl.contains(host) and remoteUrl.contains(location):
      return remoteName
  showError(&"there is no remote that points to '{location}' at '{host}' in " &
            &"the given problem-specifications directory: '{probSpecsDir}'")

proc validate(probSpecsRepo: ProbSpecsRepo) =
  ## Raises an error if the given `probSpecsRepo` is not a valid
  ## `problem-specifications` repo that is up-to-date with upstream.
  const mainBranchName = "main"

  let probSpecsDir = probSpecsRepo.dir
  logDetailed(&"Using user-provided problem-specifications dir: {probSpecsDir}")

  # Exit if the given directory does not exist.
  if not dirExists(probSpecsDir):
    showError("the given problem-specifications directory does not exist: " &
              &"'{probSpecsDir}'")

  withDir probSpecsDir:
    # Exit if the given directory is not a git repo.
    if execCmd("git rev-parse") != 0:
      showError("the given problem-specifications directory is not a git " &
                &"repository: '{probSpecsDir}'")

    # Exit if the working directory is not clean.
    if execCmd("git diff-index --quiet HEAD") != 0: # Ignores untracked files.
      showError("the given problem-specifications working directory is not " &
                &"clean: '{probSpecsDir}'")

    # Find the name of the remote that points to upstream. Don't assume the
    # remote is called 'upstream'.
    # Exit if the repo has no remote that points to upstream.
    const upstreamHost = "github.com"
    const upstreamLocation = "exercism/problem-specifications"
    let remoteName = getNameOfRemote(probSpecsDir, upstreamHost, upstreamLocation)

    # For now, just exit with an error if the HEAD is not up-to-date with
    # upstream, even if it's possible to do a fast-forward merge.
    if execCmd(&"git fetch --quiet {remoteName} {mainBranchName}") != 0:
      showError(&"failed to fetch `{mainBranchName}` in " &
                &"problem-specifications directory: '{probSpecsDir}'")

    # Allow HEAD to be on a non-`main` branch, as long as it's up-to-date
    # with `upstream/main`.
    let (revHead, _) = execCmdEx("git rev-parse HEAD")
    let (revUpstream, _) = execCmdEx(&"git rev-parse {remoteName}/{mainBranchName}")
    if revHead != revUpstream:
      showError("the given problem-specifications directory is not " &
                &"up-to-date: '{probSpecsDir}'")

proc findProbSpecsExercises*(conf: Conf): seq[ProbSpecsExercise] =
  if conf.action.probSpecsDir.len > 0:
    let probSpecsRepo = ProbSpecsRepo(dir: conf.action.probSpecsDir)
    if not conf.action.offline:
      probSpecsRepo.validate()
    result = probSpecsRepo.findProbSpecsExercises(conf)
  else:
    let probSpecsRepo = initProbSpecsRepo()
    try:
      probSpecsRepo.remove()
      probSpecsRepo.clone()
      result = probSpecsRepo.findProbSpecsExercises(conf)
    finally:
      probSpecsRepo.remove()
