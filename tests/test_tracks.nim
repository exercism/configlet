# This file implements tests for `src/tracks.nim`
import std/[os, osproc, parseutils, sets, strformat, unittest]
import "."/[cli, sync/tracks]

func oneLine(s: string): string =
  ## Returns the string `s`, but:
  ## - replaces each newline character with a single space.
  ## - strips all per-line leading whitespace.
  ## - strips trailing whitespace.
  result = newStringOfCap(s.len)
  var i = 0
  var line: string
  while i < s.len:
    i += s.skipWhitespace(i)
    i += s.parseUntil(line, '\n', i)
    result.add line
    result.add " "
  # Remove final two space characters.
  result.setLen(result.len - 2)

proc main =
  suite "findTrackExercises":
    const trackDir = ".test_tracks_nim_track_repo"
    removeDir(trackDir)
    let cmd = &"git clone --quiet https://github.com/exercism/nim.git {trackDir}"
    if execCmd(cmd) != 0:
      stderr.writeLine "Error: failed to clone the track repo"
      quit(1)

    const gitHash = "6e909c9e5338cd567c20224069df00e031fb2efa"
    if execCmd(&"git -C {trackDir} checkout --quiet {gitHash}") != 0:
      stderr.writeLine "Error: could not checkout a specific commit"
      quit(1)

    let conf = Conf(
      action: initAction(actSync),
      trackDir: trackDir,
    )
    let trackExercises = findTrackExercises(conf)

    test "returns the expected number of exercises":
      check:
        trackExercises.len == 68

    # Here, just test against the string representation of each object (as we
    # don't want to export more types from `tracks.nim` just for testing).
    # This is one way of testing the public interface rather than implementation
    # details.
    test "returns the expected object for `hello-world`":
      const expectedHelloWorld = """
        (slug: "hello-world",
        tests: (included: {"af9ffe10-dc13-42d8-a742-e7bdafac449d"},
                excluded: {}),
        repoExercise: (dir: ""))
      """.oneLine()

      check:
        trackExercises[0].`$` == expectedHelloWorld

    test "returns the expected object for `two-fer`":
      const expectedTwoFer = """
        (slug: "two-fer",
        tests: (included: {"1cf3e15a-a3d7-4a87-aeb3-ba1b43bc8dce",
                           "3549048d-1a6e-4653-9a79-b0bda163e8d5",
                           "b4c6dbb8-b4fb-42c2-bafd-10785abe7709"},
                excluded: {}),
        repoExercise: (dir: ""))
      """.oneLine()
      check:
        trackExercises[1].`$` == expectedTwoFer

    removeDir(trackDir)

main()
{.used.}
