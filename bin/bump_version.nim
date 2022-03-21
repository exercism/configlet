#!/usr/bin/env -S nim r --verbosity:0 --skipParentCfg:on

## Running this file will:
## 1. Switch to the `main` branch, if there are no uncommitted changes (exiting
##    otherwise).
## 2. Pull the upstream `main` branch from github.com/exercism/configlet.
## 3. Check that the local `main` is not ahead of upstream.
## 4. Create and switch to a new git branch named like `release-x.y.z`.
## 5. Increment the version in `configlet.version` if it exists, otherwise in
##    the Nimble file (the former is required to support pre-release version
##    strings like `4.0.0-alpha.36`).
## 6. Commit the change.
## 7. If `gh` is installed, prompt the user to push to GitHub and create the PR.
## 8. Switch back to the `main` branch.
import std/[os, osproc, strformat, strscans, strutils]

type
  BumpError = object of CatchableError
  BumpQuit = object of CatchableError

proc error(msg: string) =
  ## Raises a `BumpError`.
  raise newException(BumpError, msg)

proc exit0(msg: string) =
  ## Raises a `BumpQuit`.
  raise newException(BumpQuit, msg)

type
  Command = enum
    GitAdd = "git add"
    GitBranch = "git branch"
    GitCheckout = "git checkout"
    GitCommit = "git commit"
    GitDescribe = "git describe"
    GitDiff = "git diff"
    GitLog = "git log"
    GitLsFiles = "git ls-files"
    GitPull = "git pull"
    GitPush = "git push"
    GitRemote = "git remote"
    GitRevParse = "git rev-parse"
    GhPr = "gh pr"

proc exec(command: Command; args: openArray[string] = []): (string, int) =
  ## Runs the given command with `args`, and returns the output and exit code.
  var cmd = $command
  for arg in args:
    cmd.add ' '
    cmd.add quoteShell(arg)
  result = execCmdEx(cmd)

proc execAndCheck(command: Command; args: openArray[string] = [];
                  errorMsg = ""): string =
  ## Runs the given command with `args` and returns the output (without a final
  ## newline).
  ##
  ## Raises `BumpError` and prints `errorMsg` if the command's exit code is
  ## non-zero.
  var errC = -1
  (result, errC) = exec(command, args)
  if errC != 0:
    stderr.writeLine result
    if errorMsg.len > 0:
      error(errorMsg)
    else:
      error(&"""the exit code was non-zero: {command} {args.join(" ")}""")
  stripLineEnd result

proc getGitHubRemoteName(owner, repo: static string): string =
  ## Returns the name of the remote in that points to `github.com/owner/repo`.
  ##
  ## Raises `BumpError` if there is no such remote.
  let remotes = execAndCheck(GitRemote, ["-v"])
  const url = &"github.com/{owner}/{repo}"
  for line in remotes.splitLines():
    const pattern = &"$s$w$s$+{url}$+fetch)$."
    let (isMatch, remoteName, _, _) = line.scanTuple(pattern)
    if isMatch:
      return remoteName
  error(&"there is no remote that points to '{url}'")

proc checkRepoState =
  ## Raises `BumpError` if any of these is not satisfied:
  ## - There are no changes in the working directory.
  ## - We can switch to the `main` branch.
  ## - We can pull the `main` branch from upstream.
  ## - The local `main` branch is even with upstream.
  discard execAndCheck(GitDiff, ["--quiet"],
                       "working directory has unstaged changes")
  discard execAndCheck(GitDiff, ["--quiet", "--cached"],
                       "working directory has staged changes")
  let branchName = execAndCheck(GitBranch, ["--show-current"])
  if branchName != "main":
    stderr.writeLine "Switching to the 'main' branch..."
    discard execAndCheck(GitCheckout, ["main"])
  let remoteName = getGitHubRemoteName("exercism", "configlet")
  stderr.writeLine &"Running 'git pull {remoteName} main'..."
  discard execAndCheck(GitPull, [remoteName, "main"])
  let localCommitRef = execAndCheck(GitRevParse, ["main"])
  let upstreamCommitRef = execAndCheck(GitRevParse, [&"{remoteName}/main"])
  if localCommitRef != upstreamCommitRef:
    error("local `main` is ahead of upstream")

type
  Version {.requiresInit.} = object
    major: int
    minor: int
    patch: int
    pre: string
    n: int

func init(T: typedesc[Version]): T =
  T(major: -1, minor: -1, patch: -1, pre: "", n: -1)

func `$`(v: Version): string =
  if v.pre.len == 0:
    &"{v.major}.{v.minor}.{v.patch}"
  else:
    &"{v.major}.{v.minor}.{v.patch}-{v.pre}.{v.n}"

proc createBranchAndCheckout(version: Version) =
  ## Creates a new branch for the given `version` bump, and moves HEAD there.
  discard execAndCheck(GitCheckout, ["-b", &"release-{version}"])

proc bumpNimbleVersion(nimblePath: string): Version =
  ## Increments the version in the Nimble file at `nimblePath`, and returns the
  ## new version.
  result = Version.init()

  if fileExists(nimblePath):
    var newContents = ""

    for line in nimblePath.lines:
      if line.scanf("version$s=$s\"$i.$i.$i\"$.",
                    result.major, result.minor, result.patch):
        let currentVersion = $result
        stderr.writeLine &"The current version is {currentVersion}"
        while true:
          stderr.write "increment [major], [m]inor, [p]atch (or [q]uit)? "
          case stdin.readLine().toLowerAscii()
          of "major":
            inc result.major
            result.minor = 0
            result.patch = 0
            break
          of "m", "minor":
            inc result.minor
            result.patch = 0
            break
          of "p", "patch":
            inc result.patch
            break
          of "q", "quit":
            exit0("Quitting")
          else:
            stderr.writeLine "unrecognized choice. Try again."
        let bumpedLine = line.replace(currentVersion, $result)
        newContents.add bumpedLine
      else:
        newContents.add line
      newContents.add "\n"

    if result.major >= 0 and result.minor >= 0 and result.patch >= 0:
      createBranchAndCheckout(result)
      writeFile(nimblePath, newContents)
    else:
      error(&"could not detect version in nimble file: {nimblePath}")
  else:
    error(&"nimble file not found at path: {nimblePath}")

proc bumpVersionFile(versionFile: string): Version =
  ## Increments the version in the file at `versionFile`, and returns the new
  ## version.
  let pkgVersion = readFile(versionFile)
  result = Version.init()
  if pkgVersion.scanf("$i.$i.$i-$+.$i\n$.",
                      result.major, result.minor, result.patch,
                      result.pre, result.n):
    inc result.n
    createBranchAndCheckout(result)
    writeFile(versionFile, $result & "\n")
  else:
    error(&"the version '{pkgVersion}' is not in the expected format.")

proc bumpAndCommit: Version =
  ## Creates a new branch that bumps the version in a `configlet.version` file
  ## (if it exists), or the `configlet.nimble` file otherwise. Returns the new
  ## version.
  const
    repoRootPath = currentSourcePath.parentDir().parentDir()
    versionPath = repoRootPath / "configlet.version"

  if fileExists(versionPath):
    discard execAndCheck(GitLsFiles, ["--error-unmatch", versionPath],
                         &"file is not tracked: {versionPath}")
    result = bumpVersionFile(versionPath)
    discard execAndCheck(GitAdd, [versionPath])
  else:
    let nimblePath = repoRootPath / "configlet.nimble"
    result = bumpNimbleVersion(nimblePath)
    discard execAndCheck(GitAdd, [nimblePath])

  discard execAndCheck(GitCommit, ["-m", &"release: {result}"])
  echo "Created release commit.\n"
  echo execAndCheck(GitLog, ["-p", "-n1"])

proc genPrBody: string =
  ## Returns a suitable body for a release PR, listing every commit since the
  ## previous release.
  let previousTag = execAndCheck(GitDescribe, ["--abbrev=0"])
  result = "Let's create a release for these commits:\n"
  let commits = execAndCheck(GitLog, ["--oneline", &"{previousTag}..main"])
  for line in commits.splitLines():
    result.add "- "
    # Tweak commit titles as dependabot does, linking PRs indirectly. This
    # avoids noisy linking of referenced PRs.
    let (isMatch, lineStart, prNum) = line.scanTuple("$+ (#$i)$.")
    if isMatch:
      result.add lineStart
      result.add &" ([#{prNum}](https://github-redirect.dependabot.com/exercism/configlet/pull/{prNum}))"
    else:
      result.add line
    result.add '\n'
  stripLineEnd result

proc promptToCreatePR(bumpedVersion: Version) =
  ## Prompts to create a PR for the new version.
  let ghPath = findExe("gh")
  if ghPath.len > 0:
    while true:
      stderr.write "Push to GitHub and create the PR ([y]es/[n]o)? "
      case stdin.readLine().toLowerAscii()
      of "y", "yes":
        let remote = getGitHubRemoteName("exercism", "configlet")
        discard execAndCheck(GitPush, ["-u", remote, &"release-{bumpedVersion}"])
        let body = genPrBody()
        echo execAndCheck(GhPr,
                          ["create",
                          "--title", &"release: {bumpedVersion}",
                          "--body", body])
        discard execAndCheck(GitCheckout, ["main"])
        return
      of "n", "no":
        return
      else:
        stderr.writeLine "unrecognized choice. Try again."
  else:
    stderr.writeLine "'gh' not found. Skipping PR prompt."

proc main =
  try:
    checkRepoState()
    let bumpedVersion = bumpAndCommit()
    promptToCreatePR(bumpedVersion)
  except BumpQuit:
    let msg = getCurrentExceptionMsg()
    stderr.writeLine msg
    return
  except BumpError:
    let msg = getCurrentExceptionMsg()
    stderr.writeLine &"Error: {msg}"
    quit 1

when isMainModule:
  main()
