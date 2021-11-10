import std/[importutils, json, os, options, strformat, strutils, unittest]
import pkg/[jsony, parsetoml]
import "."/[exec, helpers, sync/sync_common]
from "."/sync/sync_filepaths {.all.} import update
from "."/sync/sync_metadata {.all.} import UpstreamMetadata, parseMetadataToml,
    metadataAreUpToDate, update

const
  testsDir = currentSourcePath().parentDir()

proc testSyncCommon =
  const trackDir = testsDir / ".test_elixir_track_repo"

  # Setup: clone a track repo, and checkout a known state
  setupExercismRepo("elixir", trackDir,
                    "8447eaeb5ae8bdd0ae94383e6ec5bcfa21a7f993") # 2021-10-28

  const conceptExercisesDir = joinPath(trackDir, "exercises", "concept")
  const practiceExercisesDir = joinPath(trackDir, "exercises", "practice")
  privateAccess(ConceptExerciseConfig)
  privateAccess(PracticeExerciseConfig)

  suite "parseFile":
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
        test_runner: none(bool)
      )
      let exerciseConfig = parseFile(dartsConfigPath, PracticeExerciseConfig)
      check exerciseConfig == expected

  suite "pretty serialization":
    test "empty Concept Exercise":
      const empty = ConceptExerciseConfig()
      const expected = """{
        "authors": [],
        "files": {
          "solution": [],
          "test": [],
          "exemplar": []
        },
        "blurb": ""
      }
      """.dedent(6)
      check:
        empty.pretty() == expected

    test "empty Practice Exercise":
      const empty = PracticeExerciseConfig()
      const expected = """{
        "authors": [],
        "files": {
          "solution": [],
          "test": [],
          "example": []
        },
        "blurb": ""
      }
      """.dedent(6)
      check:
        empty.pretty() == expected

    test "populated Concept Exercise":
      const exerciseConfig = ConceptExerciseConfig(
        authors: @["author1"],
        contributors: some(@["contributor1"]),
        files: ConceptExerciseFiles(
          solution: @["lasagna.foo"],
          test: @["test_lasagna.foo"],
          exemplar: @[".meta/exemplar.foo"],
          editor: @["extra_file.foo"]
        ),
        language_versions: ">=1.2.3",
        forked_from: some(@["bar/lovely-lasagna"]),
        icon: "myicon",
        blurb: "Learn about the basics of Foo by following a lasagna recipe.",
        source: "mysource",
        source_url: "https://example.com"
      )
      const expected = """{
        "authors": [
          "author1"
        ],
        "contributors": [
          "contributor1"
        ],
        "files": {
          "solution": [
            "lasagna.foo"
          ],
          "test": [
            "test_lasagna.foo"
          ],
          "exemplar": [
            ".meta/exemplar.foo"
          ],
          "editor": [
            "extra_file.foo"
          ]
        },
        "language_versions": ">=1.2.3",
        "forked_from": [
          "bar/lovely-lasagna"
        ],
        "icon": "myicon",
        "blurb": "Learn about the basics of Foo by following a lasagna recipe.",
        "source": "mysource",
        "source_url": "https://example.com"
      }
      """.dedent(6)
      check:
        exerciseConfig.pretty() == expected

    test "populated Practice Exercise":
      const exerciseConfig = PracticeExerciseConfig(
        authors: @["author1"],
        contributors: some(@["contributor1"]),
        files: PracticeExerciseFiles(
          solution: @["darts.foo"],
          test: @["test_darts.foo"],
          example: @[".meta/example.foo"],
          editor: @["extra_file.foo"]
        ),
        language_versions: ">=1.2.3",
        test_runner: some(false),
        blurb: "Write a function that returns the earned points in a single toss of a Darts game.",
        source: "Inspired by an exercise created by a professor Della Paolera in Argentina",
        source_url: "https://example.com"
      )
      const expected = """{
        "authors": [
          "author1"
        ],
        "contributors": [
          "contributor1"
        ],
        "files": {
          "solution": [
            "darts.foo"
          ],
          "test": [
            "test_darts.foo"
          ],
          "example": [
            ".meta/example.foo"
          ],
          "editor": [
            "extra_file.foo"
          ]
        },
        "language_versions": ">=1.2.3",
        "test_runner": false,
        "blurb": "Write a function that returns the earned points in a single toss of a Darts game.",
        "source": "Inspired by an exercise created by a professor Della Paolera in Argentina",
        "source_url": "https://example.com"
      }
      """.dedent(6)
      check:
        exerciseConfig.pretty() == expected

    test "test_runner: true is omitted":
      const exerciseConfig = PracticeExerciseConfig(
        test_runner: some(true)
      )
      const expected = """{
        "authors": [],
        "files": {
          "solution": [],
          "test": [],
          "example": []
        },
        "blurb": ""
      }
      """.dedent(6)
      check:
        exerciseConfig.pretty() == expected

    proc serializeViaRoundtrip(e: ConceptExerciseConfig | PracticeExerciseConfig): string =
      var j = e.toJson().parseJson()
      if j["contributors"].len == 0:
        delete(j, "contributors")
      if j["files"]["editor"].len == 0:
        delete(j["files"], "editor")
      when e is ConceptExerciseConfig:
        let kind = j["forked_from"].kind
        if kind == JNull or kind == JArray and j["forked_from"].len == 0:
          delete(j, "forked_from")
        if j["icon"].getStr().len == 0:
          delete(j, "icon")
      when e is PracticeExerciseConfig:
        let kind = j["test_runner"].kind
        if kind == JNull or kind == JBool and j["test_runner"].getBool():
          delete(j, "test_runner")
      for k in ["language_versions", "source", "source_url"]:
        if j[k].getStr().len == 0:
          delete(j, k)
      result = j.pretty()
      result.add '\n'

    test "with every Elixir Concept Exercise":
      for exerciseDir in getSortedSubdirs(conceptExercisesDir.Path):
        let exerciseConfigPath = joinPath(exerciseDir.string, ".meta",  "config.json")
        let exerciseConfig = parseFile(exerciseConfigPath, ConceptExerciseConfig)
        let ourSerialization = exerciseConfig.pretty()
        let serializationViaRoundtrip = exerciseConfig.serializeViaRoundtrip()
        check ourSerialization == serializationViaRoundtrip

    test "with every Elixir Practice Exercise":
      for exerciseDir in getSortedSubdirs(practiceExercisesDir.Path):
        let exerciseConfigPath = joinPath(exerciseDir.string, ".meta",  "config.json")
        let exerciseConfig = parseFile(exerciseConfigPath, PracticeExerciseConfig)
        let ourSerialization = exerciseConfig.pretty()
        let serializationViaRoundtrip = exerciseConfig.serializeViaRoundtrip()
        check ourSerialization == serializationViaRoundtrip

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
        test_runner: none(bool)
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
        test_runner: none(bool)
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
