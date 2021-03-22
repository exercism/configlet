import ".."/cli
import "."/[concept_exercises, concepts, practice_exercises, track_config]

proc allChecksPass(trackDir: string): bool =
  ## Returns true if all the linting checks pass for the track at `trackDir`.
  # We avoid some short-circuit evaluation here (e.g. due to `and`) because we
  # want to see errors from later checks even if earlier ones return `false`.
  let checks = [
    isTrackConfigValid(trackDir),
    conceptExerciseFilesExist(trackDir),
    practiceExerciseFilesExist(trackDir),
    conceptFilesExist(trackDir),
    isEveryConceptLinksFileValid(trackDir),
    isEveryConceptExerciseConfigValid(trackDir),
    isEveryPracticeExerciseConfigValid(trackDir),
  ]
  result = true

  for check in checks:
    if not check:
      return false

proc lint*(conf: Conf) =
  echo "The lint command is under development.\n" &
       "Please re-run this command regularly to see if your track passes " &
       "the latest linting rules.\n"

  let trackDir = conf.trackDir

  if allChecksPass(trackDir):
    echo """
Basic linting finished successfully:
- config.json exists and is valid JSON
- config.json has these valid fields: language, slug, active, blurb, version, tags
- Every concept has the required .md files and links.json file
- Every concept links.json file is valid
- Every concept exercise has the required .md files and a .meta/config.json file
- Every concept exercise .meta/config.json file is valid
- Every practice exercise has the required .md files and a .meta/config.json file
- Every practice exercise .meta/config.json file is valid"""
  else:
    echo """
Configlet detected at least one problem.
For more information on resolving the problems, please see the documentation:
https://github.com/exercism/docs/blob/main/building/configlet/lint.md"""
    quit(1)
