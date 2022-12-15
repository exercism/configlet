import std/[importutils, json, os, options, random, strutils, unittest]
import pkg/jsony
import "."/[exec, helpers, sync/sync_common, types_exercise_config]

const
  testsDir = currentSourcePath().parentDir()

proc testFmt =
  const trackDir = testsDir / ".test_elixir_track_repo"

  # Setup: clone a track repo, and checkout a known state
  setupExercismRepo("elixir", trackDir,
                    "8447eaeb5ae8bdd0ae94383e6ec5bcfa21a7f993") # 2021-10-28

  const conceptExercisesDir = joinPath(trackDir, "exercises", "concept")
  const practiceExercisesDir = joinPath(trackDir, "exercises", "practice")

  suite "fmt":
    privateAccess(ConceptExerciseConfig)
    privateAccess(PracticeExerciseConfig)
    privateAccess(ConceptExerciseFiles)
    privateAccess(PracticeExerciseFiles)

    block:
      const emptyConceptExerciseContents = """
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
      const emptyPracticeExerciseContents = """
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

      test "empty Concept Exercise":
        let empty = ConceptExerciseConfig()
        check:
          empty.pretty(pmFmt) == emptyConceptExerciseContents

      test "empty Practice Exercise":
        let empty = PracticeExerciseConfig()
        check:
          empty.pretty(pmFmt) == emptyPracticeExerciseContents

      test "reorders mandatory keys - Concept Exercise":
        let empty = ConceptExerciseConfig(
          originalKeyOrder: @[eckBlurb, eckAuthors, eckFiles]
        )
        check:
          empty.pretty(pmFmt) == emptyConceptExerciseContents

      test "reorders mandatory keys - Practice Exercise":
        let empty = PracticeExerciseConfig(
          originalKeyOrder: @[eckBlurb, eckAuthors, eckFiles]
        )
        check:
          empty.pretty(pmFmt) == emptyPracticeExerciseContents

    test "omits optional keys that have an empty value - Concept Exercise":
      let p = ConceptExerciseConfig(
        originalKeyOrder: @[eckContributors, eckFiles, eckLanguageVersions,
                            eckForkedFrom, eckIcon, eckRepresenter, eckSource,
                            eckSourceUrl, eckCustom],
        contributors: some(newSeq[string]()),
        files: ConceptExerciseFiles(
          originalKeyOrder: @[fkEditor],
        ),
        custom: some(newJObject())
      )
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
        p.pretty(pmFmt) == expected

    test "omits optional keys that have an empty value - Practice Exercise":
      let p = PracticeExerciseConfig(
        originalKeyOrder: @[eckContributors, eckFiles, eckLanguageVersions,
                            eckRepresenter, eckSource, eckSourceUrl, eckCustom],
        contributors: some(newSeq[string]()),
        files: PracticeExerciseFiles(
          originalKeyOrder: @[fkEditor],
        ),
        custom: some(newJObject())
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
        p.pretty(pmFmt) == expected

    block:
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
      randomize()

      test "populated config with random key order - Concept Exercise":
        var exerciseConfig = ConceptExerciseConfig(
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
        """.dedent(8)

        for i in 1..100:
          shuffle(exerciseConfig.originalKeyOrder)
          shuffle(exerciseConfig.files.originalKeyOrder)
          check:
            exerciseConfig.pretty(pmFmt) == expected

      test "populated config with random key order - Practice Exercise":
        var exerciseConfig = PracticeExerciseConfig(
          originalKeyOrder: @[eckAuthors, eckContributors, eckFiles,
                              eckLanguageVersions, eckTestRunner,
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
        """.dedent(8)

        for i in 1..100:
          shuffle(exerciseConfig.originalKeyOrder)
          shuffle(exerciseConfig.files.originalKeyOrder)
          check:
            exerciseConfig.pretty(pmFmt) == expected

    test "fmt omits `test_runner: true`":
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
        "blurb": ""
      }
      """.dedent(6)
      check:
        exerciseConfig.pretty(pmFmt) == expected

    block:
      # This checks that we format every exercise `.meta/config.json` file in
      # the `exercism/elixir` repo the same as a convoluted round-trip
      # serialization process that uses `jsony.toJson` -> `json.parseJson` and
      # then conditionally removes some key/value pairs.
      #
      # If this test fails, the problem might be in the round-trip
      # serialization. For example, it's easy to miss or introduce a bug like
      #     if j["icon"].len == 0:
      #       delete(j, "icon")
      # which compiles, but doesn't do what was intended (`getStr` is missing).
      proc fmtViaRoundtrip(e: ConceptExerciseConfig |
                              PracticeExerciseConfig): string =
        var j = e.toJson().parseJson()
        delete(j, "originalKeyOrder")
        if j["contributors"].len == 0:
          delete(j, "contributors")
        delete(j["files"], "originalKeyOrder")
        if j["files"]["editor"].len == 0:
          delete(j["files"], "editor")
        if j["files"]["invalidator"].len == 0:
          delete(j["files"], "invalidator")
        when e is ConceptExerciseConfig:
          let val = j["forked_from"]
          if val.kind == JNull or (val.kind == JArray and val.len == 0):
            delete(j, "forked_from")
          if j["icon"].getStr().len == 0:
            delete(j, "icon")
        when e is PracticeExerciseConfig:
          let val = j["test_runner"]
          # Strip `"test_runner": true`
          if val.kind == JNull or (val.kind == JBool and val.getBool()):
            delete(j, "test_runner")
        if j["representer"].kind != JObject or j["representer"].len == 0:
          delete(j, "representer")
        for k in ["language_versions", "source", "source_url"]:
          if j[k].getStr().len == 0:
            delete(j, k)
        if j["custom"].kind != JObject or j["custom"].len == 0:
          delete(j, "custom")
        result = j.pretty()
        result.add '\n'

      test "with every Elixir Concept Exercise":
        for exerciseDir in getSortedSubdirs(conceptExercisesDir.Path):
          let exerciseConfigPath = joinPath(exerciseDir.string, ".meta", "config.json")
          let exerciseConfig = parseFile(exerciseConfigPath, ConceptExerciseConfig)
          let ourSerialization = exerciseConfig.pretty(pmFmt)
          let stdlibSerialization = fmtViaRoundtrip(exerciseConfig)
          check ourSerialization == stdlibSerialization

      test "with every Elixir Practice Exercise":
        for exerciseDir in getSortedSubdirs(practiceExercisesDir.Path):
          let exerciseConfigPath = joinPath(exerciseDir.string, ".meta", "config.json")
          let exerciseConfig = parseFile(exerciseConfigPath, PracticeExerciseConfig)
          let ourSerialization = exerciseConfig.pretty(pmFmt)
          let stdlibSerialization = fmtViaRoundtrip(exerciseConfig)
          check ourSerialization == stdlibSerialization

proc main =
  testFmt()

main()
{.used.}
