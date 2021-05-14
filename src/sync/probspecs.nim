import std/[json, os, osproc, strformat, strscans, strutils]
import ".."/[cli, helpers, logger]

type
  ProbSpecsExerciseDir = distinct string

  ProbSpecsDir = distinct string

  ProbSpecsTestCase* = object
    json*: JsonNode

  ProbSpecsExercise* = object
    slug*: string
    testCases*: seq[ProbSpecsTestCase]

proc `$`(p: ProbSpecsDir): string {.borrow.}
proc `/`(head: ProbSpecsDir, tail: string): string {.borrow.}
proc `/`(head: ProbSpecsExerciseDir, tail: string): string {.borrow.}
proc dirExists(dir: ProbSpecsDir): bool {.borrow.}
proc extractFilename(path: ProbSpecsExerciseDir): string {.borrow.}
proc removeDir(dir: ProbSpecsDir, checkDir = false) {.borrow.}

proc execCmdException*(cmd: string, message: string) =
  if execCmd(cmd) != 0:
    quit(message)

proc clone(probSpecsDir: ProbSpecsDir) =
  let cmd = &"git clone --quiet --depth 1 https://github.com/exercism/problem-specifications.git {probSpecsDir}"
  logNormal(&"Cloning the problem-specifications repo into {probSpecsDir}...")
  execCmdException(cmd, "Could not clone problem-specifications repo")

func canonicalDataFile(probSpecsExerciseDir: ProbSpecsExerciseDir): string =
  probSpecsExerciseDir / "canonical-data.json"

proc exercisesWithCanonicalData(probSpecsDir: ProbSpecsDir): seq[ProbSpecsExerciseDir] =
  for dir in walkDirs(probSpecsDir / "exercises" / "*"):
    let probSpecsExerciseDir = ProbSpecsExerciseDir(dir)
    if fileExists(probSpecsExerciseDir.canonicalDataFile()):
      result.add(probSpecsExerciseDir)

func slug(probSpecsExerciseDir: ProbSpecsExerciseDir): string =
  extractFilename(probSpecsExerciseDir)

func initProbSpecsTestCase(node: JsonNode): ProbSpecsTestCase =
  ProbSpecsTestCase(json: node)

proc uuid*(testCase: ProbSpecsTestCase): string =
  testCase.json["uuid"].getStr()

proc description*(testCase: ProbSpecsTestCase): string =
  testCase.json["description"].getStr()

func isReimplementation*(testCase: ProbSpecsTestCase): bool =
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

proc parseProbSpecsTestCases(probSpecsExerciseDir: ProbSpecsExerciseDir): seq[ProbSpecsTestCase] =
  if probSpecsExerciseDir.slug == "grains":
    probSpecsExerciseDir.canonicalDataFile().grainsWorkaround().initProbSpecsTestCases()
  else:
    probSpecsExerciseDir.canonicalDataFile().parseFile().initProbSpecsTestCases()

proc initProbSpecsExercise(probSpecsExerciseDir: ProbSpecsExerciseDir): ProbSpecsExercise =
  ProbSpecsExercise(
    slug: probSpecsExerciseDir.slug,
    testCases: parseProbSpecsTestCases(probSpecsExerciseDir),
  )

proc findProbSpecsExercises(probSpecsDir: ProbSpecsDir, conf: Conf): seq[ProbSpecsExercise] =
  for probSpecsExerciseDir in probSpecsDir.exercisesWithCanonicalData():
    if conf.action.exercise.len == 0 or conf.action.exercise == probSpecsExerciseDir.slug:
      result.add(initProbSpecsExercise(probSpecsExerciseDir))

proc getNameOfRemote(probSpecsDir: ProbSpecsDir; host, location: string): string =
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

proc validate(probSpecsDir: ProbSpecsDir) =
  ## Raises an error if the given `probSpecsRepo` is not a valid
  ## `problem-specifications` repo that is up-to-date with upstream.
  const mainBranchName = "main"

  logDetailed(&"Using user-provided problem-specifications dir: {probSpecsDir}")

  # Exit if the given directory does not exist.
  if not dirExists(probSpecsDir):
    showError("the given problem-specifications directory does not exist: " &
              &"'{probSpecsDir}'")

  withDir probSpecsDir.string:
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
    let probSpecsDir = ProbSpecsDir(conf.action.probSpecsDir)
    if not conf.action.offline:
      validate(probSpecsDir)
    result = findProbSpecsExercises(probSpecsDir, conf)
  else:
    let probSpecsDir = ProbSpecsDir(getCurrentDir() / ".problem-specifications")
    try:
      removeDir(probSpecsDir)
      clone(probSpecsDir)
      result = findProbSpecsExercises(probSpecsDir, conf)
    finally:
      removeDir(probSpecsDir)
