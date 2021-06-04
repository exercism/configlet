switch("styleCheck", "hint")
hint("Name", on)
switch("experimental", "strictFuncs")

# Replace the stdlib JSON modules with our own stricter versions.
patchFile("stdlib", "json", "src/json")
patchFile("stdlib", "parsejson", "src/parsejson")

if defined(release):
  switch("opt", "size")
  switch("passC", "-flto")

  if defined(linux) or defined(windows):
    switch("passL", "-s")
    switch("passL", "-static")

  if defined(linux):
    switch("gcc.exe", "musl-gcc")
    switch("gcc.linkerexe", "musl-gcc")
