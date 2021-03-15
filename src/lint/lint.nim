import ".."/cli
import "."/[concept_exercises, concepts, track_config]

proc lint*(conf: Conf) =
  echo "The lint command is under development.\n" &
       "Please re-run this command regularly to see if your track passes " &
       "the latest linting rules.\n"

  let trackDir = conf.trackDir
  let b1 = isTrackConfigValid(trackDir)
  let b2 = conceptExerciseFilesExist(trackDir)
  let b3 = conceptFilesExist(trackDir)
  let b4 = isEveryConceptExerciseConfigValid(trackDir)

  if b1 and b2 and b3 and b4:
    echo """
Basic linting finished successfully:
- config.json exists and is valid JSON
- config.json has these valid fields: language, slug, active, blurb, version, tags
- Every concept has the required .md files and links.json file
- Every concept exercise has the required .md files and a .meta/config.json file
- Every concept exercise .meta/config.json file is valid"""
  else:
    quit(1)
