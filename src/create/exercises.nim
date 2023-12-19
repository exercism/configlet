import std/[os, strformat]
import ".."/[cli, helpers, sync/sync, types_track_config]
import "."/[approaches, articles]

proc createConceptExercise*(conf: Conf) =
  echo "create ce"

proc createPracticeExercise*(conf: Conf) =
  echo "create pe"
