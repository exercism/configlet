import std/[hashes, os, parseutils, strutils]

proc gorgeCheck(cmd, errorMsg: string): string =
  ## Executes `cmd` at compile time and returns its text output (stdout + stderr).
  ##
  ## Raises an exception if the exit code is non-zero, using the given `errorMsg`.
  var exitCode = -1
  (result, exitCode) = gorgeEx(cmd)
  result.stripLineEnd()
  if exitCode != 0:
    echo result
    raise newException(OSError, errorMsg)

type
  PackagePaths = object
    cligen: string

proc init(T: typedesc[PackagePaths]): T =
  ## Returns the absolute paths to Nimble packages that we patch.
  # Optimization: call `nimble path` only once.
  result = T()
  let output = block:
    var cmd = "nimble path"
    for fieldName, _ in result.fieldPairs:
      cmd.add " " & fieldName
    gorgeCheck(cmd, "failed to get path to packages")
  var i = 0
  for fieldVal in result.fields:
    i += output.parseUntil(fieldVal, {'\n'}, i) + 1

proc patch(dir, patchPath: string;
           files: varargs[tuple[relPath: string, patchedHash: int64]]) =
  ## Checks that each file in `files` has the corresponding `patchedHash`, and
  ## if not, applies the patch at `patchPath` to `dir`.
  ##
  ## Raises an exception if the patch could not be applied.
  # We want to support running `nimble build` before the package is installed,
  # so we can't `import foo` to check the package's behavior directly.
  # Instead, hash the files and then run `git apply` when necessary.
  # Use `std/hashes` to hash - note that we can't import `std/md5` or `std/sha1`
  # in a .nimble file.
  for (relPath, patchedHash) in files:
    if readFile(dir / relPath).hash().int64 != patchedHash:
      # Apply the patch.
      let cmd = "git -C " & dir & " apply --verbose " & patchPath
      discard gorgeCheck(cmd, "failed to apply patch")
      break

proc patchCligen(packagePaths: PackagePaths) =
  # Patch `cligen/parseopt3` so that "--foo --bar" is parsed as two long options,
  # even when `longNoVal` is both non-empty and lacks `foo`.
  const thisDir = currentSourcePath().parentDir()
  patch(
    packagePaths.cligen,
    thisDir / "parseopt3_allow_long_option_optional_value.patch",
    ("cligen" / "parseopt3.nim", 3589591455'i64)
  )

proc ensureThatNimblePackagesArePatched* =
  let packagePaths = PackagePaths.init()
  patchCligen packagePaths
