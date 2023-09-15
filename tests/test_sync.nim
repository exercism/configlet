import std/[importutils, json, os, options, strutils, unittest]
import exec, fmt/exercises, helpers, sync/sync_common,
    types_exercise_config, types_track_config
from sync/sync_filepaths {.all.} import update
from sync/sync_metadata {.all.} import UpstreamMetadata, parseMetadataToml,
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
  privateAccess(ConceptExerciseFiles)
  privateAccess(PracticeExerciseFiles)

  suite "parseFile":
    test "with a Concept Exercise":
      const lasagnaDir = joinPath(conceptExercisesDir, "lasagna")
      const lasagnaConfigPath = joinPath(lasagnaDir, ".meta", "config.json")
      let expected = ConceptExerciseConfig(
        originalKeyOrder: @[eckBlurb, eckAuthors, eckContributors, eckFiles,
                            eckForkedFrom, eckLanguageVersions],
        authors: @["neenjaw"],
        contributors: some(@["angelikatyborska"]),
        files: ConceptExerciseFiles(
          originalKeyOrder: @[fkSolution, fkTest, fkExemplar],
          solution: @["lib/lasagna.ex"],
          test: @["test/lasagna_test.exs"],
          exemplar: @[".meta/exemplar.ex"],
          editor: @[]
        ),
        language_versions: ">=1.10",
        forked_from: some(@["csharp/lucians-luscious-lasagna"]),
        icon: "",
        blurb: "Learn about the basics of Elixir by following a lasagna recipe.",
        source: none(string),
        source_url: none(string)
      )
      let exerciseConfig = parseFile(lasagnaConfigPath, ConceptExerciseConfig)
      check exerciseConfig == expected

    test "with a Practice Exercise":
      const dartsDir = joinPath(practiceExercisesDir, "darts")
      const dartsConfigPath = joinPath(dartsDir, ".meta", "config.json")
      let expected = PracticeExerciseConfig(
        originalKeyOrder: @[eckAuthors, eckContributors, eckFiles, eckBlurb,
                            eckSource],
        authors: @["jiegillet"],
        contributors: some(@["angelikatyborska"]),
        files: PracticeExerciseFiles(
          originalKeyOrder: @[fkExample, fkSolution, fkTest],
          solution: @["lib/darts.ex"],
          test: @["test/darts_test.exs"],
          example: @[".meta/example.ex"],
          editor: @[]
        ),
        language_versions: "",
        test_runner: none(bool),
        blurb: "Write a function that returns the earned points in a single toss of a Darts game.",
        source: some("Inspired by an exercise created by a professor Della Paolera in Argentina"),
        source_url: none(string)
      )
      let exerciseConfig = parseFile(dartsConfigPath, PracticeExerciseConfig)
      check exerciseConfig == expected

  suite "pretty serialization":
    test "empty Concept Exercise":
      let empty = ConceptExerciseConfig()
      const expected = """
      {
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
        empty.prettyExerciseConfig(pmSync) == expected

    test "empty Practice Exercise":
      let empty = PracticeExerciseConfig()
      const expected = """
      {
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
        empty.prettyExerciseConfig(pmSync) == expected

    test "Practice Exercise with `custom` key having value of the empty object":
      let p = PracticeExerciseConfig(
        originalKeyOrder: @[eckAuthors, eckCustom],
        authors: @["foo", "bar"],
        custom: some(newJObject())
      )
      const expected = """{
        "authors": [
          "foo",
          "bar"
        ],
        "files": {
          "solution": [],
          "test": [],
          "example": []
        },
        "blurb": "",
        "custom": {}
      }
      """.dedent(6)
      check:
        p.prettyExerciseConfig(pmSync) == expected

    let customJson = """
      {
        "foo": true,
        "bar": 7,
        "baz": "hi",
        "stuff": [1, 2, 3],
        "my_object": {
          "foo": false,
          "bar": ["a", "b", "c"]
        }
      }
    """.parseJson()

    test "populated Concept Exercise":
      let exerciseConfig = ConceptExerciseConfig(
        originalKeyOrder: @[eckAuthors, eckContributors, eckFiles,
                            eckLanguageVersions, eckForkedFrom, eckIcon,
                            eckRepresenter, eckBlurb, eckSource, eckSourceUrl,
                            eckCustom],
        authors: @["author1"],
        contributors: some(@["contributor1"]),
        files: ConceptExerciseFiles(
          originalKeyOrder: @[fkSolution, fkTest, fkExemplar, fkEditor],
          solution: @["lasagna.foo"],
          test: @["test_lasagna.foo"],
          exemplar: @[".meta/exemplar.foo"],
          editor: @["extra_file.foo"]
        ),
        language_versions: ">=1.2.3",
        forked_from: some(@["bar/lovely-lasagna"]),
        icon: "myicon",
        representer: some(Representer(version: 42)),
        blurb: "Learn about the basics of Foo by following a lasagna recipe.",
        source: some("mysource"),
        source_url: some("https://example.com"),
        custom: some(customJson)
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
        "representer": {
          "version": 42
        },
        "blurb": "Learn about the basics of Foo by following a lasagna recipe.",
        "source": "mysource",
        "source_url": "https://example.com",
        "custom": {
          "foo": true,
          "bar": 7,
          "baz": "hi",
          "stuff": [
            1,
            2,
            3
          ],
          "my_object": {
            "foo": false,
            "bar": [
              "a",
              "b",
              "c"
            ]
          }
        }
      }
      """.dedent(6)
      check:
        exerciseConfig.prettyExerciseConfig(pmSync) == expected

    test "populated Practice Exercise":
      let exerciseConfig = PracticeExerciseConfig(
        originalKeyOrder: @[eckAuthors, eckContributors, eckFiles,
                            eckLanguageVersions, eckTestRunner, eckIcon,
                            eckRepresenter, eckBlurb, eckSource, eckSourceUrl,
                            eckCustom],
        authors: @["author1"],
        contributors: some(@["contributor1"]),
        files: PracticeExerciseFiles(
          originalKeyOrder: @[fkSolution, fkTest, fkExample, fkEditor],
          solution: @["darts.foo"],
          test: @["test_darts.foo"],
          example: @[".meta/example.foo"],
          editor: @["extra_file.foo"]
        ),
        language_versions: ">=1.2.3",
        test_runner: some(false),
        icon: "myicon",
        representer: some(Representer(version: 42)),
        blurb: "Write a function that returns the earned points in a single toss of a Darts game.",
        source: some("Inspired by an exercise created by a professor Della Paolera in Argentina"),
        source_url: some("https://example.com"),
        custom: some(customJson)
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
        "icon": "myicon",
        "representer": {
          "version": 42
        },
        "blurb": "Write a function that returns the earned points in a single toss of a Darts game.",
        "source": "Inspired by an exercise created by a professor Della Paolera in Argentina",
        "source_url": "https://example.com",
        "custom": {
          "foo": true,
          "bar": 7,
          "baz": "hi",
          "stuff": [
            1,
            2,
            3
          ],
          "my_object": {
            "foo": false,
            "bar": [
              "a",
              "b",
              "c"
            ]
          }
        }
      }
      """.dedent(6)
      check:
        exerciseConfig.prettyExerciseConfig(pmSync) == expected

    test "test_runner: true is not omitted when not formatting":
      let exerciseConfig = PracticeExerciseConfig(
        originalKeyOrder: @[eckTestRunner],
        test_runner: some(true)
      )
      const expected = """{
        "authors": [],
        "files": {
          "solution": [],
          "test": [],
          "example": []
        },
        "test_runner": true,
        "blurb": ""
      }
      """.dedent(6)
      check:
        exerciseConfig.prettyExerciseConfig(pmSync) == expected

    test "pretty: can use `pmSync` when an optional key has the value `null`":
      let exerciseConfig = PracticeExerciseConfig(
        originalKeyOrder: @[eckContributors],
        contributors: none(seq[string])
      )
      const expected = """{
        "authors": [],
        "contributors": null,
        "files": {
          "solution": [],
          "test": [],
          "example": []
        },
        "blurb": ""
      }
      """.dedent(6)
      check:
        exerciseConfig.prettyExerciseConfig(pmSync) == expected

    proc stdlibSerialize(path: string): string =
      var j = json.parseFile(path)
      for key in j.keys():
        if key == "title":
          j.delete(key)
      result = j.pretty()
      result.add '\n'

    test "with every Elixir Concept Exercise":
      for exerciseDir in getSortedSubdirs(conceptExercisesDir.Path):
        let exerciseConfigPath = joinPath(exerciseDir.string, ".meta", "config.json")
        let exerciseConfig = parseFile(exerciseConfigPath, ConceptExerciseConfig)
        let ourSerialization = exerciseConfig.prettyExerciseConfig(pmSync)
        let stdlibSerialization = stdlibSerialize(exerciseConfigPath)
        check ourSerialization == stdlibSerialization

    test "with every Elixir Practice Exercise":
      for exerciseDir in getSortedSubdirs(practiceExercisesDir.Path):
        let exerciseConfigPath = joinPath(exerciseDir.string, ".meta", "config.json")
        let exerciseConfig = parseFile(exerciseConfigPath, PracticeExerciseConfig)
        let ourSerialization = exerciseConfig.prettyExerciseConfig(pmSync)
        let stdlibSerialization = stdlibSerialize(exerciseConfigPath)
        check ourSerialization == stdlibSerialization

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
    let psDir = getCacheDir() / "exercism" / "configlet" / "problem-specifications"

    # Setup: clone the problem-specifications repo, and checkout a known state
    setupExercismRepo("problem-specifications", psDir,
                      "7b395a76b22bbd2d2f471dbf60eb3872e6906632") # 2021-10-30

    privateAccess(UpstreamMetadata)
    let psExercisesDir = joinPath(psDir, "exercises")

    test "with only `blurb`":
      let metadataPath = joinPath(psExercisesDir, "all-your-base", "metadata.toml")
      const expected = UpstreamMetadata(
        blurb: "Convert a number, represented as a sequence of digits in one base, to any other base.",
        source: none(string),
        source_url: none(string)
      )
      let metadata = parseMetadataToml(metadataPath)
      check metadata == expected

    test "with only `blurb` and `source`":
      let metadataPath = joinPath(psExercisesDir, "darts", "metadata.toml")
      const expected = UpstreamMetadata(
        blurb: "Write a function that returns the earned points in a single toss of a Darts game.",
        source: some("Inspired by an exercise created by a professor Della Paolera in Argentina"),
        source_url: none(string)
      )
      let metadata = parseMetadataToml(metadataPath)
      check metadata == expected

    test "with only `blurb` and `source_url` (and quote escaping)":
      let metadataPath = joinPath(psExercisesDir, "two-fer", "metadata.toml")
      const expected = UpstreamMetadata(
        blurb: """Create a sentence of the form "One for X, one for me.".""",
        source: none(string),
        source_url: some("https://github.com/exercism/problem-specifications/issues/757")
      )
      let metadata = parseMetadataToml(metadataPath)
      check metadata == expected

    test "with `blurb`, `source`, and `source_url`":
      let metadataPath = joinPath(psExercisesDir, "collatz-conjecture", "metadata.toml")
      const expected = UpstreamMetadata(
        blurb: "Calculate the number of steps to reach 1 using the Collatz conjecture.",
        source: some("An unsolved problem in mathematics named after mathematician Lothar Collatz"),
        source_url: some("https://en.wikipedia.org/wiki/3x_%2B_1_problem")
      )
      let metadata = parseMetadataToml(metadataPath)
      check metadata == expected

    test "with `blurb`, `source`, and `source_url`, and extra `title`":
      let metadataPath = joinPath(psExercisesDir, "etl", "metadata.toml")
      const expected = UpstreamMetadata(
        blurb: "We are going to do the `Transform` step of an Extract-Transform-Load.",
        source: some("The Jumpstart Lab team"),
        source_url: some("http://jumpstartlab.com")
      )
      let metadata = parseMetadataToml(metadataPath)
      check metadata == expected

    # Don't leave cached prob-specs dir in detached HEAD state.
    check git(["-C", psDir, "checkout", "main"]).exitCode == 0

  suite "update and metadataAreUpToDate":
    privateAccess(UpstreamMetadata)
    privateAccess(PracticeExerciseConfig)

    test "updates `blurb`, `source`, and `source_url`":
      const metadata = UpstreamMetadata(
        blurb: "This is a really good exercise.",
        source: some("From a conversation with ee7."),
        source_url: some("https://example.com")
      )
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
        test_runner: none(bool),
        blurb: "",
        source: none(string),
        source_url: none(string)
      )
      update(p, metadata)
      let expected = PracticeExerciseConfig(
        originalKeyOrder: @[eckBlurb, eckSource, eckSourceUrl],
        authors: @["foo"],
        contributors: some(@["foo"]),
        files: PracticeExerciseFiles(
          solution: @["foo"],
          test: @["foo"],
          example: @["foo"],
          editor: @[]
        ),
        language_versions: "",
        test_runner: none(bool),
        blurb: "This is a really good exercise.",
        source: some("From a conversation with ee7."),
        source_url: some("https://example.com")
      )
      check:
        p == expected
        metadataAreUpToDate(p, metadata)

    test "removes `source_url` that previously existed":
      const metadata = UpstreamMetadata(
        blurb: "This is a really good exercise.",
        source: some("From a conversation with ee7."),
        source_url: none(string)
      )
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
        test_runner: none(bool),
        blurb: "",
        source: some("From a conversation with ee7."),
        source_url: some("https://example.com")
      )
      update(p, metadata)
      let expected = PracticeExerciseConfig(
        originalKeyOrder: @[eckBlurb, eckSource],
        authors: @["foo"],
        contributors: some(@["foo"]),
        files: PracticeExerciseFiles(
          solution: @["foo"],
          test: @["foo"],
          example: @["foo"],
          editor: @[]
        ),
        language_versions: "",
        test_runner: none(bool),
        blurb: "This is a really good exercise.",
        source: some("From a conversation with ee7."),
        source_url: none(string)
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
