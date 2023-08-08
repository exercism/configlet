switch("styleCheck", "error")
hint("Name", on)
warning("BareExcept", off)
warning("ProveInit", off)
warning("Uninit", off)
switch("experimental", "strictDefs")
switch("experimental", "strictFuncs")
switch("define", "nimStrictDelete")
switch("mm", "refc")

# Replace the stdlib JSON modules with our own stricter versions.
patchFile("stdlib", "json", "src/patched_stdlib/json")
patchFile("stdlib", "parsejson", "src/patched_stdlib/parsejson")

if defined(release):
  switch("opt", "size")
  switch("passC", "-flto")
  switch("passL", "-flto")

  if defined(linux) or defined(windows):
    switch("passL", "-s")
    switch("passL", "-static")

  if defined(linux):
    if defined(gcc):
      switch("gcc.exe", "musl-gcc")
      switch("gcc.linkerexe", "musl-gcc")
    elif defined(clang):
      switch("clang.exe", "musl-clang")
      switch("clang.linkerexe", "musl-clang")
