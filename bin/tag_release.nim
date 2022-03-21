#!/usr/bin/env -S nim r --verbosity:0 --skipParentCfg:on

## Running this file will:
## 1. Switch to the `main` branch, if there are no uncommitted changes (exiting
##    otherwise).
## 2. Pull the upstream `main` branch from github.com/exercism/configlet.
## 3. Check that the local `main` branch is not ahead of upstream.
## 4. Check that the most recent commit on the `main` branch is an untagged
##    release commit.
## 5. Prompt the user to tag the commit and push the tag to exercism/configlet,
##    which will trigger a build job and create a draft release.
import std/[strformat, strscans, strutils]
import "."/bump_version

proc checkRepoIsInPreTagState: string =
  ## Returns the to-be-tagged version.
  checkRepoState()
  let commitTitle = execAndCheck(GitLog, ["-n1", "--format='%s'"])
  let (isMatch, version, _) = commitTitle.scanTuple("release: $+ (#$i)$.")
  if isMatch:
    let existingTag = execAndCheck(GitTag, ["--points-at"])
    if existingTag.len > 0:
      error(&"the commit has already been tagged: {existingTag}")
    result = version
  else:
    error(&"the most recent commit on branch 'main' is not a release commit:\n    {commitTitle}")

proc promptToTagAndPush(version: string) =
  while true:
    stderr.write "tag the current commit and push the tag to exercism/configlet? ([y]es/[n]o) "
    case stdin.readLine().toLowerAscii()
    of "y", "yes":
      discard execAndCheck(GitTag, ["-a", "-m", version, version])
      let remote = getGitHubRemoteName("exercism", "configlet")
      discard execAndCheck(GitPush, [remote, version])
      echo &"Successfully pushed tag for {version}"
      echo """
        Remaining steps to release:
        1. Edit the release notes to contain the list of user-facing changes,
           separating by features and bug fixes.
        2. Wait for every build job to finish.
        3. Check that CI is green.
        4. Un-draft the release.
      """.unindent()
      return
    of "n", "no":
      return
    else:
      stderr.writeLine "unrecognized choice. Try again."

proc main =
  try:
    let bumpedVersion = checkRepoIsInPreTagState()
    promptToTagAndPush(bumpedVersion)
  except BumpError:
    let msg = getCurrentExceptionMsg()
    stderr.writeLine &"Error: {msg}"
    quit 1

when isMainModule:
  main()
