import strformat
import probspecsrepo
import syncer

const NimblePkgVersion {.strdefine}: string = "unknown"

proc main: void =
  echo &"Exercism Canonical Data Syncer v{NimblePkgVersion}"

  try:
    removeProbSpecsRepo()
    cloneProbSpecsRepo()
    syncExercisesData()
  except:
    echo fmt"Error: {getCurrentExceptionMsg()}"
  # finally:
    removeProbSpecsRepo() 

main()