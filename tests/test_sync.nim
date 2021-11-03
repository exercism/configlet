import std/[importutils, os, strformat, unittest]
import pkg/parsetoml
import "."/[exec, sync/sync_common]
from "."/sync/sync_metadata {.all.} import UpstreamMetadata, parseMetadataToml,
    metadataAreUpToDate, update

const
  testsDir = currentSourcePath().parentDir()

proc testSyncCommon =
  suite "parseFile":
    const trackDir = testsDir / ".test_elixir_track_repo"

    # Setup: clone a track repo, and checkout a known state
    setupExercismRepo("elixir", trackDir,
                      "8447eaeb5ae8bdd0ae94383e6ec5bcfa21a7f993") # 2021-10-28

    const conceptExercisesDir = joinPath(trackDir, "exercises", "concept")
    const practiceExercisesDir = joinPath(trackDir, "exercises", "practice")
    privateAccess(ConceptExerciseConfig)
    privateAccess(PracticeExerciseConfig)

    test "with a Concept Exercise":
      const lasagnaDir = joinPath(conceptExercisesDir, "lasagna")
      const lasagnaConfigPath = joinPath(lasagnaDir, ".meta", "config.json")
      const expected = ConceptExerciseConfig(
        authors: @["neenjaw"],
        contributors: @["angelikatyborska"],
        files: ConceptExerciseFiles(
          solution: @["lib/lasagna.ex"],
          test: @["test/lasagna_test.exs"],
          exemplar: @[".meta/exemplar.ex"],
          editor: @[]
        ),
        language_versions: ">=1.10",
        blurb: "Learn about the basics of Elixir by following a lasagna recipe.",
        source: "",
        source_url: "",
        forked_from: @["csharp/lucians-luscious-lasagna"],
        icon: ""
      )
      let exerciseConfig = parseFile(lasagnaConfigPath, ConceptExerciseConfig)
      check exerciseConfig == expected

    test "with a Practice Exercise":
      const dartsDir = joinPath(practiceExercisesDir, "darts")
      const dartsConfigPath = joinPath(dartsDir, ".meta", "config.json")
      const expected = PracticeExerciseConfig(
        authors: @["jiegillet"],
        contributors: @["angelikatyborska"],
        files: PracticeExerciseFiles(
          solution: @["lib/darts.ex"],
          test: @["test/darts_test.exs"],
          example: @[".meta/example.ex"],
          editor: @[]
        ),
        language_versions: "",
        blurb: "Write a function that returns the earned points in a single toss of a Darts game.",
        source: "Inspired by an exercise created by a professor Della Paolera in Argentina",
        source_url: "",
        test_runner: ""
      )
      let exerciseConfig = parseFile(dartsConfigPath, PracticeExerciseConfig)
      check exerciseConfig == expected

proc testSyncMetadata =
  suite "parseMetadataToml":
    const psDir = testsDir / ".test_problem_specifications"

    # Setup: clone the problem-specifications repo, and checkout a known state
    setupExercismRepo("problem-specifications", psDir,
                      "7b395a76b22bbd2d2f471dbf60eb3872e6906632") # 2021-10-30

    privateAccess(UpstreamMetadata)
    const psExercisesDir = joinPath(psDir, "exercises")

    test "with only `blurb`":
      const metadataPath = joinPath(psExercisesDir, "all-your-base", "metadata.toml")
      const expected = UpstreamMetadata(
        blurb: "Convert a number, represented as a sequence of digits in one base, to any other base.",
        source: "",
        source_url: ""
      )
      let metadata = parseMetadataToml(metadataPath)
      check metadata == expected

    test "with only `blurb` and `source`":
      const metadataPath = joinPath(psExercisesDir, "darts", "metadata.toml")
      const expected = UpstreamMetadata(
        blurb: "Write a function that returns the earned points in a single toss of a Darts game.",
        source: "Inspired by an exercise created by a professor Della Paolera in Argentina",
        source_url: ""
      )
      let metadata = parseMetadataToml(metadataPath)
      check metadata == expected

    test "with only `blurb` and `source_url` (and quote escaping)":
      const metadataPath = joinPath(psExercisesDir, "two-fer", "metadata.toml")
      const expected = UpstreamMetadata(
        blurb: """Create a sentence of the form "One for X, one for me.".""",
        source: "",
        source_url: "https://github.com/exercism/problem-specifications/issues/757"
      )
      let metadata = parseMetadataToml(metadataPath)
      check metadata == expected

    test "with `blurb`, `source`, and `source_url`":
      const metadataPath = joinPath(psExercisesDir, "collatz-conjecture", "metadata.toml")
      const expected = UpstreamMetadata(
        blurb: "Calculate the number of steps to reach 1 using the Collatz conjecture.",
        source: "An unsolved problem in mathematics named after mathematician Lothar Collatz",
        source_url: "https://en.wikipedia.org/wiki/3x_%2B_1_problem"
      )
      let metadata = parseMetadataToml(metadataPath)
      check metadata == expected

    test "with `blurb`, `source`, and `source_url`, and extra `title`":
      const metadataPath = joinPath(psExercisesDir, "etl", "metadata.toml")
      const expected = UpstreamMetadata(
        blurb: "We are going to do the `Transform` step of an Extract-Transform-Load.",
        source: "The Jumpstart Lab team",
        source_url: "http://jumpstartlab.com"
      )
      let metadata = parseMetadataToml(metadataPath)
      check metadata == expected

    # The below test will fail if the latest state of `problem-specifications`
    # contains a `metadata.toml` file that we cannot parse.

    # Checkout the latest `problem-specifications` commit. During CI, our clone
    # of that repo is fresh (and also not a shallow clone) so this really does
    # checkout the latest upstream ref. Locally, it may not.
    setupExercismRepo("problem-specifications", psDir, "main")

    test "can parse every `metadata.toml` file in `problem-specifications`":
      # Check that we get the same `blurb`, `source`, and `source_url` as
      # `pkg/parsetoml`, which passes a TOML parsing test suite.
      for metadataPath in walkFiles(&"{psExercisesDir}/*/metadata.toml"):
        let toml = parsetoml.parseFile(metadataPath)
        let expected = UpstreamMetadata(
          blurb: if toml.hasKey("blurb"): $toml["blurb"] else: "",
          source: if toml.hasKey("source"): $toml["source"] else: "",
          source_url: if toml.hasKey("source_url"): $toml["source_url"] else: ""
        )
        let metadata = parseMetadataToml(metadataPath)
        check metadata == expected

  suite "update and metadataAreUpToDate":
    privateAccess(UpstreamMetadata)
    privateAccess(PracticeExerciseConfig)
    const metadata = UpstreamMetadata(
      blurb: "This is a really good exercise.",
      source: "From a conversation with ee7.",
      source_url: "https://example.com"
    )

    test "updates `blurb`, `source`, and `source_url`":
      var p = PracticeExerciseConfig(
        authors: @["foo"],
        contributors: @["foo"],
        files: PracticeExerciseFiles(
          solution: @["foo"],
          test: @["foo"],
          example: @["foo"],
          editor: @[]
        ),
        language_versions: "",
        blurb: "",
        source: "",
        source_url: "",
        test_runner: ""
      )
      update(p, metadata)
      const expected = PracticeExerciseConfig(
        authors: @["foo"],
        contributors: @["foo"],
        files: PracticeExerciseFiles(
          solution: @["foo"],
          test: @["foo"],
          example: @["foo"],
          editor: @[]
        ),
        language_versions: "",
        blurb: "This is a really good exercise.",
        source: "From a conversation with ee7.",
        source_url: "https://example.com",
        test_runner: ""
        )
      check:
        p == expected
        metadataAreUpToDate(p, metadata)

proc main =
  testSyncCommon()
  testSyncMetadata()

main()
{.used.}
