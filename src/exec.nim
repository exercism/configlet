import std/[os, osproc, streams, strformat, strtabs, strutils]

type
  ProcessResult* = tuple
    output: string
    exitCode: int

proc exec(command: string; args: openArray[string] = [];
    options: set[ProcessOption] = {poStdErrToStdOut, poUsePath};
    env: StringTableRef = nil; workingDir = ""; input = ""): ProcessResult {.
    gcsafe, tags: [ExecIOEffect, ReadIOEffect, RootEffect].} =
  ## Runs the `command` with `args`, and returns the output and exit code.
  ## The `options`, `env`, and `workingDir` parameters behave as for
  ## `startProcess`. If `input.len > 0`, it is passed as stdin.
  ##
  ## This is a convenience wrapper around `startProcess`, and is minimally
  ## adapted from `osproc.execCmdEx` to use `args` (and avoid `poEvalCommand`).
  ##
  ## Raises `OSError` if the `command` is not found.
  var p = startProcess(command, args = args, options = options, env = env,
                       workingDir = workingDir)
  var outp = outputStream(p)

  if input.len > 0:
    inputStream(p).write(input)
  close inputStream(p)

  result = ("", -1)
  var line = newStringOfCap(120)
  while true:
    if outp.readLine(line):
      result[0].add line
      result[0].add "\n"
    else:
      result[1] = peekExitCode(p)
      if result[1] != -1:
        break
  close(p)

proc git*(args: openArray[string]): ProcessResult =
  ## Runs `git` with `args`. Returns the output and exit code.
  result = exec("git", args = args)

proc execAndCheck*(expectedExitCode: int; command: string;
                   args: openArray[string] = [];
                   options: set[ProcessOption] = {poStdErrToStdOut, poUsePath};
                   env: StringTableRef = nil; workingDir = ""; input = "";
                   msg = ""; verbose = false): string =
  ## Runs `command` with `args`, and if the exit code is `expectedExitCode`,
  ## returns the output.
  ##
  ## Otherwise, prints the output and `msg`, and raises `OSError`.
  if verbose:
    let argsString = args.join(" ")
    stderr.write &"Running `{command} {argsString}`... "
  var exitCode = int.high
  (result, exitCode) = exec(command, args, options, env, workingDir, input)
  if verbose:
    let statusMsg = if exitCode == 0: "success" else: "failure"
    stderr.writeLine statusMsg
  if exitCode != expectedExitCode:
    stderr.writeLine result
    if msg.len > 0:
      stderr.writeLine msg
    elif not verbose:
      let argsString = args.join(" ")
      stderr.writeLine &"Error when running `{command} {argsString}`"
    raise newException(OSError, "")

proc gitCheck*(expectedExitCode: int; args: openArray[string] = [];
               msg = ""): string =
  ## Runs `git` with `args`, and if the exit code is `expectedExitCode`,
  ## returns the output.
  ##
  ## Otherwise, prints the output and `msg`, then raises `OSError`.
  result = execAndCheck(expectedExitCode, "git", args, msg = msg)

proc cloneExercismRepo*(repoName, dest: string; shallow = false;
                        singleBranch = true) =
  ## Clones the Exercism repo named `repoName` to `dest`. Performs a shallow
  ## clone if `shallow` is `true`, and clones only the default branch if
  ## `singleBranch` is `true`.
  ##
  ## Quits if the clone is unsuccessful.
  let url = &"https://github.com/exercism/{repoName}/"
  let args = block:
    var res = @["clone"]
    if shallow:
      res.add ["--depth", "1"]
    if singleBranch:
      res.add ["--single-branch"]
    res.add ["--", url, dest]
    res
  stderr.write &"Cloning {url}... "
  let (outp, exitCode) = git(args)
  if exitCode == 0:
    stderr.writeLine "success"
  else:
    stderr.writeLine "failure"
    stderr.writeLine outp
    quit 1

proc gitCheckout(dir, hash: string) =
  ## Checkout `hash` in the git repo at `dir`, discarding changes to the working
  ## directory in `dir`.
  ##
  ## Quits if unsucessful.
  let args = ["-C", dir, "checkout", "--force", hash]
  discard gitCheck(0, args)

proc setupExercismRepo*(repoName, dest, hash: string; shallow = false) =
  ## If there is no directory at `dest`, clones the Exercism repo named
  ## `repoName` to `dest`.
  ##
  ## Then checkout the given `hash` in `dest`.
  if not dirExists(dest):
    cloneExercismRepo(repoName, dest, shallow)
  gitCheckout(dest, hash)

func conciseDiff(s: string): string =
  ## Returns the lines of `s` that begin with a `+` or `-` character.
  result = newStringOfCap(s.len)
  for line in s.splitLines():
    if line.len > 0:
      if line[0] in {'+', '-'}:
        result.add line
        result.add '\n'

proc gitDiffConcise*(dir: string): string =
  let diffArgs = ["--no-pager", "-C", dir, "diff", "--no-ext-diff", "--text",
                  "--unified=0", "--no-prefix", "--color=never"]
  result = gitCheck(0, diffArgs).conciseDiff()

proc gitDiffExitCode*(trackDir: string): int =
  let args = ["-C", trackDir, "diff", "--exit-code"]
  result = git(args).exitCode
