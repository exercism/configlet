import std/[os, osproc, unittest]
import exec, helpers

const
  testsDir* = currentSourcePath().parentDir()
  repoRootDir* = testsDir.parentDir()

template execAndCheckExitCode*(expectedExitCode: int; cmd: string;
                               inputStr = "") =
  ## Runs `cmd`, supplying `inputStr` on stdin, and checks that its exit code is
  ## `expectedExitCode`
  let exitCode = execCmdEx(cmd, input = inputStr)[1]
  check:
    exitCode == expectedExitCode

template execAndCheck*(expectedExitCode: int; cmd, expectedOutput: string;
                       inputStr = "") =
  ## Runs `cmd`, supplying `inputStr` on stdin, and checks that:
  ## - its exit code is `expectedExitCode`
  ## - its output is `expectedOutput`
  let (outp, exitCode) = execCmdEx(cmd, input = inputStr)
  check:
    exitCode == expectedExitCode
    outp == expectedOutput

template gitRestore*(dir, arg: string) =
  let args = ["-C", dir, "restore", arg]
  check git(args).exitCode == 0

template testDiffThenRestore*(dir, expectedDiff, restoreArg: string) =
  ## Runs `git diff` in `dir`, and tests that the output is `expectedDiff`. Then
  ## runs `git restore` with the argument `restoreArg`.
  test "the diff is as expected":
    let diff = gitDiffConcise(trackDir)
    check diff == expectedDiff
  gitRestore(dir, restoreArg)

template checkNoDiff*(trackDir: string) =
  check gitDiffExitCode(trackDir) == 0
