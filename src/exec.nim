import std/[osproc, streams, strtabs]

type
  ProcessResult* = tuple
    output: string
    exitCode: int

proc myExecCmdEx*(command: string; args: openArray[string] = [];
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
  ## Raises `OSError` if we cannot execute a file at `path`.
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
  result = myExecCmdEx("git", args = args)
