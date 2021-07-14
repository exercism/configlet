import ".."/[cli, helpers]
import "."/[concept_exercises, concepts, docs, practice_exercises,
            track_config, validators]

proc allChecksPass(trackDir: Path): bool =
  ## Returns true if all the linting checks pass for the track at `trackDir`.
  # We avoid some short-circuit evaluation here (e.g. due to `and`) because we
  # want to see errors from later checks even if earlier ones return `false`.
  let checks = [
    isTrackConfigValid(trackDir),
    conceptExerciseDocsExist(trackDir),
    practiceExerciseDocsExist(trackDir),
    conceptDocsExist(trackDir),
    isEveryConceptLinksFileValid(trackDir),
    isEveryConceptConfigValid(trackDir),
    isEveryConceptExerciseConfigValid(trackDir),
    isEveryPracticeExerciseConfigValid(trackDir),
    sharedExerciseDocsExist(trackDir),
  ]
  result = allTrue(checks)

proc lint*(conf: Conf) =
  echo "The lint command is under development.\n" &
       "Please re-run this command regularly to see if your track passes " &
       "the latest linting rules.\n"

  let trackDir = Path(conf.trackDir)

  if allChecksPass(trackDir):
    echo """
Basic linting finished successfully:
- config.json exists and is valid JSON
- config.json has these valid fields:
    language, slug, active, blurb, version, status, online_editor, key_features, tags
- Every concept has the required .md files
- Every concept has a valid links.json file
- Every concept has a valid .meta/config.json file
- Every concept exercise has the required .md files
- Every concept exercise has a valid .meta/config.json file
- Every practice exercise has the required .md files
- Every practice exercise has a valid .meta/config.json file
- The required shared exercise docs are present"""
  else:
    echo """
Configlet detected at least one problem.
For more information on resolving the problems, please see the documentation:
https://github.com/exercism/docs/blob/main/building/configlet/lint.md"""
    quit(1)
