import std/[importutils, os, options, strformat, unittest]
import pkg/parsetoml
import "."/[exec, sync/sync_common]
from "."/sync/sync_filepaths {.all.} import Slug, update
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
        contributors: some(@["angelikatyborska"]),
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
        forked_from: some(@["csharp/lucians-luscious-lasagna"]),
        icon: ""
      )
      let exerciseConfig = parseFile(lasagnaConfigPath, ConceptExerciseConfig)
      check exerciseConfig == expected

    test "with a Practice Exercise":
      const dartsDir = joinPath(practiceExercisesDir, "darts")
      const dartsConfigPath = joinPath(dartsDir, ".meta", "config.json")
      const expected = PracticeExerciseConfig(
        authors: @["jiegillet"],
        contributors: some(@["angelikatyborska"]),
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
        test_runner: true
      )
      let exerciseConfig = parseFile(dartsConfigPath, PracticeExerciseConfig)
      check exerciseConfig == expected

proc testSyncFilepaths =
  suite "update":
    const helloWorldSlug = Slug("hello-world")

    block:
      const patterns = FilePatterns(
        solution: @["lib/%{snake_slug}.ex"],
        test: @["test/%{snake_slug}_test.exs"],
        example: @[".meta/example.ex"],
        exemplar: @[".meta/exemplar.ex"],
        editor: @["abc"],
      )

      test "synced Concept Exercise":
        const fBefore = ConceptExerciseFiles(
          solution: @["foo"],
          test: @["foo"],
          exemplar: @["foo"],
          editor: @["foo"],
        )
        var f = fBefore
        update(f, patterns, helloWorldSlug)
        check f == fBefore

      test "synced Practice Exercise":
        const fBefore = PracticeExerciseFiles(
          solution: @["foo"],
          test: @["foo"],
          example: @["foo"],
          editor: @["foo"],
        )
        var f = fBefore
        update(f, patterns, helloWorldSlug)
        check f == fBefore

    test "unsynced Concept Exercise":
      const patterns = FilePatterns(
        solution: @["lib/%{snake_slug}.ex"],
        test: @["test/%{snake_slug}_test.exs"],
        example: @[".meta/example.ex"],
        exemplar: @[".meta/exemplar.ex"],
      )
      const expected = ConceptExerciseFiles(
        solution: @["lib/hello_world.ex"],
        test: @["test/hello_world_test.exs"],
        exemplar: @[".meta/exemplar.ex"],
      )
      var f = ConceptExerciseFiles()
      update(f, patterns, helloWorldSlug)
      check f == expected

    test "unsynced Practice Exercise":
      const patterns = FilePatterns(
        solution: @["Sources/%{pascal_slug}/%{pascal_slug}.swift"],
        test: @["Tests/%{pascal_slug}Tests/%{pascal_slug}Tests.swift"],
        example: @[".meta/Sources/%{pascal_slug}/%{pascal_slug}Example.swift"],
        exemplar: @[".meta/Sources/%{pascal_slug}/%{pascal_slug}Exemplar.swift"],
      )
      const expected = PracticeExerciseFiles(
        solution: @["Sources/HelloWorld/HelloWorld.swift"],
        test: @["Tests/HelloWorldTests/HelloWorldTests.swift"],
        example: @[".meta/Sources/HelloWorld/HelloWorldExample.swift"],
      )
      var f = PracticeExerciseFiles()
      update(f, patterns, helloWorldSlug)
      check f == expected

    block:
      const patterns = FilePatterns(
        solution: @["prefix/%{snake_slug}.foo"],
        test: @["prefix/test-%{kebab_slug}.foo"],
        example: @[".meta/%{camel_slug}Example.foo"],
        exemplar: @[".meta/%{pascal_slug}Exemplar.foo"],
        editor: @["%{snake_slug}.bar"],
      )

      test "every placeholder - Concept Exercise":
        const expected = ConceptExerciseFiles(
          solution: @["prefix/hello_world.foo"],
          test: @["prefix/test-hello-world.foo"],
          exemplar: @[".meta/HelloWorldExemplar.foo"],
          editor: @["hello_world.bar"],
        )
        var f = ConceptExerciseFiles()
        update(f, patterns, helloWorldSlug)
        check f == expected

      test "every placeholder - Practice Exercise":
        const expected = PracticeExerciseFiles(
          solution: @["prefix/hello_world.foo"],
          test: @["prefix/test-hello-world.foo"],
          example: @[".meta/helloWorldExample.foo"],
          editor: @["hello_world.bar"],
        )
        var f = PracticeExerciseFiles()
        update(f, patterns, helloWorldSlug)
        check f == expected

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
        contributors: some(@["foo"]),
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
        test_runner: true
      )
      update(p, metadata)
      const expected = PracticeExerciseConfig(
        authors: @["foo"],
        contributors: some(@["foo"]),
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
        test_runner: true
        )
      check:
        p == expected
        metadataAreUpToDate(p, metadata)

proc main =
  testSyncCommon()
  testSyncFilepaths()
  testSyncMetadata()

main()
{.used.}
