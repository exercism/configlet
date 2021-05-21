import std/[json, os, osproc, strformat, strscans, strutils, tables]
import ".."/[cli, helpers, logger]

type
  ProbSpecsDir {.requiresInit.} = distinct string

  ProbSpecsExerciseDir {.requiresInit.} = distinct string

  ProbSpecsTestCase* = distinct JsonNode

  ProbSpecsExercises* = Table[string, seq[ProbSpecsTestCase]]

proc `$`(p: ProbSpecsDir): string {.borrow.}
proc dirExists(dir: ProbSpecsDir): bool {.borrow.}
proc removeDir(dir: ProbSpecsDir, checkDir = false) {.borrow.}
proc `/`(head: ProbSpecsDir, tail: string): string {.borrow.}
proc `/`(head: ProbSpecsExerciseDir, tail: string): string {.borrow.}
proc lastPathPart(path: ProbSpecsExerciseDir): string {.borrow.}
proc `[]`(testCase: ProbSpecsTestCase, name: string): JsonNode {.borrow.}
proc hasKey(testCase: ProbSpecsTestCase, key: string): bool {.borrow.}
proc pretty*(testcase: ProbSpecsTestCase, indent = 2): string {.borrow.}

proc execSuccessElseQuit(cmd: string, message: string): string =
  ## Runs `cmd` and returns its output. If the command exits with a non-zero
  ## exit code, prints the output and the given `message`, then quits.
  var errC = -1
  (result, errC) = execCmdEx(cmd)
  if errC != 0:
    stderr.writeLine result
    if message.len > 0:
      stderr.writeLine message
    else:
      stderr.writeLine &"Error when running '{cmd}'"
    quit(1)

proc clone(probSpecsDir: ProbSpecsDir) =
  ## Downloads the `exercism/problem-specifications` repo to `probSpecsDir`.
  const cmdBase = "git clone --quiet --depth 1"
  const url = "https://github.com/exercism/problem-specifications.git"
  let cmd = &"{cmdBase} {url} {probSpecsDir}"
  logNormal(&"Cloning the problem-specifications repo into {probSpecsDir}...")
  discard execSuccessElseQuit(cmd, "Could not clone problem-specifications repo")

func canonicalDataFile(probSpecsExerciseDir: ProbSpecsExerciseDir): string =
  probSpecsExerciseDir / "canonical-data.json"

func slug(probSpecsExerciseDir: ProbSpecsExerciseDir): string =
  lastPathPart(probSpecsExerciseDir)

func uuid*(testCase: ProbSpecsTestCase): string =
  testCase["uuid"].getStr()

func description*(testCase: ProbSpecsTestCase): string =
  testCase["description"].getStr()

func isReimplementation*(testCase: ProbSpecsTestCase): bool =
  testCase.hasKey("reimplements")

func reimplements*(testCase: ProbSpecsTestCase): string =
  testCase["reimplements"].getStr()

proc initProbSpecsTestCases(node: JsonNode): seq[ProbSpecsTestCase] =
  ## Returns a seq of every individual test case in `node` (flattening).
  if node.hasKey("uuid"):
    result.add ProbSpecsTestCase(node)
  elif node.hasKey("cases"):
    for childNode in node["cases"].getElems():
      result.add initProbSpecsTestCases(childNode)

proc grainsWorkaround(grainsPath: string): JsonNode =
  ## Parses the canonical data file for `grains`, replacing the too-large
  ## integers with floats. This avoids an error that otherwise occurs when
  ## parsing integers are too large to store as a 64-bit signed integer.
  let sanitised = readFile(grainsPath).multiReplace(
    ("92233720368547758", "92233720368547758.0"),
    ("184467440737095516", "184467440737095516.0"))
  result = parseJson(sanitised)

proc parseProbSpecsTestCases(probSpecsExerciseDir: ProbSpecsExerciseDir): seq[ProbSpecsTestCase] =
  ## Parses the `canonical-data.json` file for the given exercise, and returns
  ## a seq of, essentially, the JsonNode for each test.
  let canonicalJsonPath = canonicalDataFile(probSpecsExerciseDir)
  if slug(probSpecsExerciseDir) == "grains":
    canonicalJsonPath.grainsWorkaround().initProbSpecsTestCases()
  else:
    canonicalJsonPath.parseFile().initProbSpecsTestCases()

proc findProbSpecsExercises(probSpecsDir: ProbSpecsDir, conf: Conf): ProbSpecsExercises =
  ## Returns a Table containing the slug and corresponding canonical tests for
  ## each exercise in `probSpecsDir`. If `conf` specifies a single exercise,
  ## returns only the tests for that exercise.
  let pattern = if conf.action.exercise.len > 0: conf.action.exercise else: "*"
  for dir in walkDirs(probSpecsDir / "exercises" / pattern):
    let probSpecsExerciseDir = ProbSpecsExerciseDir(dir)
    if fileExists(probSpecsExerciseDir.canonicalDataFile()):
      let slug = slug(probSpecsExerciseDir)
      result[slug] = parseProbSpecsTestCases(probSpecsExerciseDir)

proc getNameOfRemote(probSpecsDir: ProbSpecsDir; host, location: string): string =
  ## Returns the name of the remote in `probSpecsDir` that points to `location`
  ## at `host`.
  ##
  ## Exits with an error if there is no such remote.
  # There's probably a better way to do this than parsing `git remote -v`.
  let msg = "could not run `git remote -v` in the given " &
            &"problem-specifications directory: '{probSpecsDir}'"
  let remotes = execSuccessElseQuit("git remote -v", msg)
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
    let revHead = execSuccessElseQuit("git rev-parse HEAD", "")
    let revUpstream = execSuccessElseQuit(&"git rev-parse {remoteName}/" &
                                          &"{mainBranchName}", "")
    if revHead != revUpstream:
      showError("the given problem-specifications directory is not " &
                &"up-to-date: '{probSpecsDir}'")

proc findProbSpecsExercises*(conf: Conf): ProbSpecsExercises =
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
