switch("styleCheck", "hint")
hint("Name", on)
switch("experimental", "strictEffects")
switch("experimental", "strictFuncs")
switch("define", "nimStrictDelete")

# Replace the stdlib JSON modules with our own stricter versions.
patchFile("stdlib", "json", "src/patched_stdlib/json")
patchFile("stdlib", "parsejson", "src/patched_stdlib/parsejson")

if defined(release):
  switch("opt", "size")
  switch("passC", "-flto")

  if defined(linux) or defined(windows):
    switch("passL", "-s")
    switch("passL", "-static")

  if defined(linux):
    switch("gcc.exe", "musl-gcc")
    switch("gcc.linkerexe", "musl-gcc")
