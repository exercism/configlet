import ".."/cli
import "."/[concept_exercises, concepts, practice_exercises, track_config]

proc lint*(conf: Conf) =
  echo "The lint command is under development.\n" &
       "Please re-run this command regularly to see if your track passes " &
       "the latest linting rules.\n"

  let trackDir = conf.trackDir
  let b1 = isTrackConfigValid(trackDir)
  let b2 = conceptExerciseFilesExist(trackDir)
  let b3 = practiceExerciseFilesExist(trackDir)
  let b4 = conceptFilesExist(trackDir)
  let b5 = isEveryConceptExerciseConfigValid(trackDir)

  if b1 and b2 and b3 and b4 and b5:
    echo """
Basic linting finished successfully:
- config.json exists and is valid JSON
- config.json has these valid fields: language, slug, active, blurb, version, tags
- Every concept has the required .md files and links.json file
- Every concept exercise has the required .md files and a .meta/config.json file
- Every concept exercise .meta/config.json file is valid
- Every practice exercise has the required .md files and a .meta/config.json file"""
  else:
    quit(1)
