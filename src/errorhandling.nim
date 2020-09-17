proc onCtrlC() {.noconv.} =
  quit()

proc setupInterruptHandler*: void =
  setControlCHook(onCtrlC)
