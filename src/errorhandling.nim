proc onCtrlC() {.noconv.} =
  quit()

proc handleExitSignal*: void =
  setControlCHook(onCtrlC)
