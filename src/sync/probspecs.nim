import std/[json, os, strformat, strscans, strutils]
import ".."/[cli, exec, helpers, logger]

type
  ProbSpecsDir* {.requiresInit.} = distinct string

  ProbSpecsExerciseDir {.requiresInit.} = distinct string

  ProbSpecsTestCase* = distinct JsonNode

  ProbSpecsTestCases* = seq[ProbSpecsTestCase]

proc `$`(dir: ProbSpecsDir): string {.borrow.}
proc dirExists(dir: ProbSpecsDir): bool {.borrow.}
proc createDir(dir: ProbSpecsDir) {.borrow.}
proc parentDir(path: ProbSpecsDir): string {.borrow.}
proc `/`*(head: ProbSpecsDir, tail: string): string {.borrow.}
proc `/`(head: ProbSpecsExerciseDir, tail: string): string {.borrow.}
proc lastPathPart(path: ProbSpecsExerciseDir): string {.borrow.}
proc `[]`(testCase: ProbSpecsTestCase, name: string): JsonNode {.borrow.}
proc hasKey(testCase: ProbSpecsTestCase, key: string): bool {.borrow.}
proc pretty*(testCase: ProbSpecsTestCase, indent = 2): string {.borrow.}

func canonicalDataFile(probSpecsExerciseDir: ProbSpecsExerciseDir): string =
  probSpecsExerciseDir / "canonical-data.json"

func slug(probSpecsExerciseDir: ProbSpecsExerciseDir): string =
  lastPathPart(probSpecsExerciseDir)

proc uuid*(testCase: ProbSpecsTestCase): string =
  testCase["uuid"].getStr()

proc description*(testCase: ProbSpecsTestCase): string =
  testCase["description"].getStr()

func isReimplementation*(testCase: ProbSpecsTestCase): bool =
  testCase.hasKey("reimplements")

proc reimplements*(testCase: ProbSpecsTestCase): string =
  testCase["reimplements"].getStr()

proc init(T: typedesc[ProbSpecsTestCases], node: JsonNode, prefix = ""): T =
  ## Returns a seq of every individual test case in `node` (flattening). We
  ## alter each `description` value to indicate any nesting, which is OK because
  ## we only use the `description` for writing `tests.toml`.
  if node.hasKey("uuid"):
    if node.hasKey("description"):
      if node["description"].kind == JString:
        node["description"].str = &"""{prefix}{node["description"].getStr()}"""
    result.add ProbSpecsTestCase(node)
  elif node.hasKey("cases"):
    let prefix =
      if node.hasKey("description"):
        &"""{prefix}{node["description"].getStr()} -> """
      else:
        prefix
    for childNode in node["cases"].getElems():
      result.add ProbSpecsTestCases.init(childNode, prefix)

proc grainsWorkaround(grainsPath: string): JsonNode =
  ## Parses the canonical data file for `grains`, replacing the too-large
  ## integers with floats. This avoids an error that otherwise occurs when
  ## parsing integers are too large to store as a 64-bit signed integer.
  let sanitised = readFile(grainsPath).multiReplace(
    ("92233720368547758", "92233720368547758.0"),
    ("184467440737095516", "184467440737095516.0"))
  result = parseJson(sanitised)

proc parseProbSpecsTestCases(probSpecsExerciseDir: ProbSpecsExerciseDir): ProbSpecsTestCases =
  ## Parses the `canonical-data.json` file for the given exercise, and returns
  ## a seq of, essentially, the JsonNode for each test.
  let canonicalJsonPath = canonicalDataFile(probSpecsExerciseDir)
  let j =
    if slug(probSpecsExerciseDir) == "grains":
      canonicalJsonPath.grainsWorkaround()
    else:
      canonicalJsonPath.parseFile()
  result = ProbSpecsTestCases.init(j)

proc getCanonicalTests*(probSpecsDir: ProbSpecsDir,
                        slug: string): ProbSpecsTestCases =
  ## Returns a seq of the canonical tests for the exercise `slug` in
  ## `probSpecsDir`.
  let probSpecsExerciseDir = joinPath(probSpecsDir.string, "exercises",
                                      slug).ProbSpecsExerciseDir
  if fileExists(probSpecsExerciseDir.canonicalDataFile()):
    result = parseProbSpecsTestCases(probSpecsExerciseDir)

proc getNameOfRemote(probSpecsDir: ProbSpecsDir;
                     host, location: string): string =
  ## Returns the name of the remote in `probSpecsDir` that points to `location`
  ## at `host`.
  ##
  ## Exits with an error if there is no such remote.
  # There's probably a better way to do this than parsing `git remote -v`.
  let msg = "could not run `git remote -v` in the cached " &
            &"problem-specifications directory: '{probSpecsDir}'"
  let remotes = gitCheck(0, ["remote", "-v"], msg)
  var remoteName, remoteUrl: string
  for line in remotes.splitLines():
    discard line.scanf("$s$w$s$+fetch)$.", remoteName, remoteUrl)
    if remoteUrl.contains(host) and remoteUrl.contains(location):
      return remoteName
  showError(&"there is no remote that points to '{location}' at '{host}' in " &
            &"the cached problem-specifications directory: '{probSpecsDir}'")

proc validate(probSpecsDir: ProbSpecsDir, conf: Conf) =
  ## Raises an error if the given `probSpecsDir` is not a valid
  ## `problem-specifications` repo that is up-to-date with upstream.
  const mainBranchName = "main"

  logDetailed(&"Using cached problem-specifications dir: {probSpecsDir}")

  withDir probSpecsDir.string:
    # Validate the `problem-specifications` repo by checking the ref of the root
    # commit. Don't support a shallow clone.
    let rootCommitRef = gitCheck(0, ["rev-list", "--max-parents=0", "HEAD"],
                                 "the directory at the cached " &
                                 "problem-specifications location is not a " &
                                 &"git repository: '{probSpecsDir}'")

    if rootCommitRef != "8ba81069dab8e96a53630f3e51446487b6ec9212\n":
      showError("the git repo at the cached problem-specifications location " &
                &"has an unexpected initial commit: '{probSpecsDir}'")

    # Exit if the working directory is not clean (allowing untracked files).
    discard gitCheck(0, ["diff-index", "--quiet", "HEAD"], "the cached " &
                     "problem-specifications working directory is not clean: " &
                     &"'{probSpecsDir}'")

    # Find the name of the remote that points to upstream. Don't assume the
    # remote is called 'upstream'.
    # Exit if the repo has no remote that points to upstream.
    const upstreamHost = "github.com"
    const upstreamLocation = "exercism/problem-specifications"
    let remoteName = getNameOfRemote(probSpecsDir, upstreamHost, upstreamLocation)

    if not conf.action.offline:
      # `fetch` and `merge` separately, for better error messages.
      logNormal(&"Running 'git pull' in cached problem-specifications dir...")
      discard gitCheck(0, ["fetch", "--quiet", remoteName, mainBranchName],
                       &"failed to fetch `{mainBranchName}` in " &
                       &"problem-specifications directory: '{probSpecsDir}'")

      discard gitCheck(0, ["merge", "--ff-only", &"{remoteName}/{mainBranchName}"],
                       &"failed to merge '{mainBranchName}' in " &
                       &"problem-specifications directory: '{probSpecsDir}'")

proc init*(T: typedesc[ProbSpecsDir], conf: Conf): T =
  result = T(getCacheDir() / "exercism" / "configlet" / "problem-specifications")
  if dirExists(result):
    validate(result, conf)
  elif conf.action.offline:
    let msg = fmt"""
      Error: --offline was passed, but there is no cached problem-specifications
      repo at '{result}'
      Please run without --offline once.""".unindent()
    stderr.writeLine msg
    quit 1
  else:
    try:
      createDir result.parentDir()
    except IOError, OSError:
      stderr.writeLine &"Error: {getCurrentExceptionMsg()}"
      quit 1
    cloneExercismRepo("problem-specifications", result.string, shallow = false)
