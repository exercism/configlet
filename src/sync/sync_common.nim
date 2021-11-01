import std/[json, strformat, strutils]
import ".."/cli

proc userSaysYes*(syncKind: SyncKind): bool =
  stderr.write &"sync the above {syncKind} ([y]es/[n]o)? "
  let resp = stdin.readLine().toLowerAscii()
  if resp == "y" or resp == "yes":
    result = true

type
  PathAndUpdatedJson* = object
    path*: string
    updatedJson*: JsonNode

proc updateFilepathsOrMetadata*(seenUnsynced: var set[SyncKind];
                                configPairs: seq[PathAndUpdatedJson];
                                conf: Conf;
                                syncKind: SyncKind) =
  ## For each item in `configPairs`, writes the JSON to the corresponding path.
  ## If successful, excludes `syncKind` from `seenUnsynced`.
  assert syncKind in {skFilepaths, skMetadata}
  if configPairs.len > 0: # Implies that `--update` was passed.
    if conf.action.yes or userSaysYes(syncKind):
      for configPair in configPairs:
        writeFile(configPair.path,
                  configPair.updatedJson.pretty() & "\n")
      seenUnsynced.excl syncKind
