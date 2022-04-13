#!/usr/bin/env -S nim r --verbosity:0 --skipParentCfg:on
import std/[algorithm, json, os, osproc, strformat, strutils, times]
import pkg/jsony

# Silence `styleCheck` hints for underscores.
{.push hint[Name]: off.}

type
  ProbSpecsExercises = object
    with_canonical_data: seq[string]
    without_canonical_data: seq[string]
    deprecated: seq[string]

  ProbSpecsState = object
    last_updated: string
    problem_specifications_commit_ref: string
    exercises: ProbSpecsExercises

{.pop.}

proc execAndCheck(cmd: string): string =
  var exitCode = -1
  (result, exitCode) = execCmdEx(cmd)
  if exitCode == 0:
    result.stripLineEnd()
  else:
    stderr.writeLine(result)
    stderr.writeLine &"Command exited non-zero: {cmd}"
    quit 1

proc getCommitTimestamp(probSpecsDir: string): string =
  let cmd = &"git -C {probSpecsDir} log -n1 --pretty=%ct"
  execAndCheck(cmd).parseInt().fromUnix().utc().`$`

proc getCommitRef(probSpecsDir: string): string =
  execAndCheck(&"git -C {probSpecsDir} rev-parse HEAD")

proc getExercises(probSpecsDir: string): ProbSpecsExercises =
  result = ProbSpecsExercises()
  for kind, path in walkDir(probSpecsDir / "exercises"):
    if kind == pcDir:
      let track = path.lastPathPart()
      if fileExists(path / ".deprecated"):
        result.deprecated.add track
      elif fileExists(path / "canonical-data.json"):
        result.with_canonical_data.add track
      else:
        result.without_canonical_data.add track
  sort result.with_canonical_data
  sort result.without_canonical_data
  sort result.deprecated

proc init(T: typedesc[ProbSpecsState], probSpecsDir: string): T =
  T(
    last_updated: getCommitTimestamp(probSpecsDir),
    problem_specifications_commit_ref: getCommitRef(probSpecsDir),
    exercises: getExercises(probSpecsDir)
  )

proc main =
  const repoRootDir = currentSourcePath().parentDir().parentDir()
  const probSpecsDir = repoRootDir.parentDir() / "problem-specifications"
  if dirExists(probSpecsDir):
    let jsonContents = ProbSpecsState.init(probSpecsDir).toJson().parseJson().pretty()
    const jsonOutputPath = repoRootDir / "src" / "info" / "prob_specs_exercises.json"
    writeFile(jsonOutputPath, jsonContents & "\n")
    echo &"Wrote updated data to '{jsonOutputPath}'"
  else:
    stderr.writeLine "This script requires a problem-specifications " &
                     "directory at this location:\n" & probSpecsDir
    quit 1

when isMainModule:
  main()
