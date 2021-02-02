switch("styleCheck", "hint")
hint("Name", on)

if defined(release):
  switch("opt", "size")
  switch("passC", "-flto")

  if defined(linux) or defined(windows):
    switch("passL", "-s")
    switch("passL", "-static")

  if defined(linux):
    switch("gcc.exe", "musl-gcc")
    switch("gcc.linkerexe", "musl-gcc")
