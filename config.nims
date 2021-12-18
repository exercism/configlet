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
    if findExe("zigcc").len > 0 and defined(amd64):
      switch("cc", "clang")
      # We can't write `zig cc` below, because the value cannot contain a space.
      switch("clang.exe", "zigcc")
      switch("clang.linkerexe", "zigcc")
      switch("passC", "-target x86_64-linux-musl")
      switch("passL", "-target x86_64-linux-musl")
    elif defined(gcc):
      switch("gcc.exe", "musl-gcc")
      switch("gcc.linkerexe", "musl-gcc")
    elif defined(clang):
      switch("clang.exe", "musl-clang")
      switch("clang.linkerexe", "musl-clang")

# Tell Nim the paths to Nimble packages. We need this because we ran `nimble lock`.
# The below lines are added by `nimble setup`.
# begin Nimble config (version 2)
--noNimblePath
when withDir(thisDir(), system.fileExists("nimble.paths")):
  include "nimble.paths"
# end Nimble config
