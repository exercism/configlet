import osproc

proc execCmdException*(cmd: string, exceptn: typedesc, message: string): void =
  if execCmd(cmd) != 0:
    raise newException(exceptn, message)
