# Configlet for Exercism v3

This is a development version of Configlet for use with v3 of Exercism.

## Usage

The application is a single binary and can be used as follows:

```
Usage:
  configlet [global-options] <command> [command-options]

Commands:
  lint, sync, uuid, generate, info

Options for sync:
  -e, --exercise <slug>        Only operate on this exercise
  -p, --prob-specs-dir <dir>   Use this 'problem-specifications' directory, rather than cloning temporarily
  -o, --offline                Do not check that the directory specified by --prob-specs-dir is up to date
  -u, --update                 Prompt to update the seen data that are unsynced
  -y, --yes                    Auto-confirm prompts from --update for updating docs, filepaths, and metadata
      --docs                   Sync Practice Exercise '.docs/introduction.md' and '.docs/instructions.md' files
      --filepaths              Populate empty 'files' values in Concept/Practice exercise '.meta/config.json' files
      --metadata               Sync Practice Exercise '.meta/config.json' metadata values
      --tests [mode]           Sync Practice Exercise '.meta/tests.toml' files.
                               The mode value specifies how missing tests are handled when using --update.
                               Allowed values: c[hoose], i[nclude], e[xclude] (default: choose)

Options for uuid:
  -n, --num <int>              Number of UUIDs to generate

Global options:
  -h, --help                   Show this help message and exit
      --version                Show this tool's version information and exit
  -t, --track-dir <dir>        Specify a track directory to use instead of the current directory
  -v, --verbosity <verbosity>  The verbosity of output.
                               Allowed values: q[uiet], n[ormal], d[etailed] (default: normal)
```

## `configlet lint`

The primary function of configlet is to do _linting_: checking if a track's configuration files are properly structured - both syntactically and semantically. Misconfigured tracks may not sync correctly, may look wrong on the website, or may present a suboptimal user experience, so configlet's guards play an important part in maintaining the integrity of Exercism.

The `configlet lint` command is still under development. The list of currently implemented checks can be found [here](https://github.com/exercism/configlet/issues/249).

## `configlet sync`

A Practice Exercise on an Exercism track is often implemented from a specification in the [`exercism/problem-specifications`](https://github.com/exercism/problem-specifications) repo.

Exercism deliberately requires that every exercise has its own copy of certain files (like `.docs/instructions.md`), even when that exercise exists in `problem-specifications`.
Therefore configlet has a `sync` command, which can check that such Practice Exercises on a track are in sync with that upstream source, and can update them when updates are available.

There are three kinds of data that can be updated from `problem-specifications`: documentation, metadata, and tests.
There is also one kind of data that can be populated from the track-level `config.json` file: filepaths in exercise config files.

We describe the checking and updating of these data kinds in individual sections below, but as a quick summary:
- `configlet sync` only operates on exercises that exist in the track-level `config.json` file. Therefore if you are implementing a new exercise on a track and want to add the initial files with `configlet sync`, please add the exercise to the track-level `config.json` file first. If the exercise is not yet ready to be user-facing, please set its `status` value to `wip`.
- A plain `configlet sync` makes no changes to the track, and checks every data kind for every exercise.
- To operate on a subset of data kinds, use some combination of the `--docs`, `--filepaths`, `--metadata`, and `--tests` options.
- To interactively update data on the track, use the `--update` option.
- To non-interactively update docs, filepaths, and metadata on the track, use `--update --yes`.
- To non-interactively include every unseen test for a given exercise, use e.g. `--update --tests include --exercise prime-factors`.
- To skip downloading the `problem-specifications` repo, add `--offline --prob-specs-dir /path/to/local/problem-specifications`
- Note that `configlet sync` tries to maintain the key order in exercise `.meta/config.json` files when updating. To write these files in a canonical form without syncing, please use the upcoming `configlet fmt` command. However, `configlet sync` _does_ add (possibly empty) required keys (`authors`, `files`, `blurb`) when they are missing. This is less "sync-like", but more ergonomic: when implementing a new exercise, you can use `sync` to create a starter `.meta/config.json` file.
- `configlet sync` removes keys that are not in the spec. Custom key/value pairs are still supported: they must be written inside a JSON object named `custom`.
- The exit code is 0 when all the seen data are synced when configlet exits, and 1 otherwise.

Note that in `configlet` releases `4.0.0-alpha.34` and earlier, the `sync` command operated only on tests.

### Docs

A Practice Exercise that is derived from the `problem-specifications` repo must have a `.docs/instructions.md` file (and possibly a `.docs/introduction.md` file too) containing the exercise documentation from `problem-specifications`.

To check every Practice Exercise on the track for available documentation updates (exiting with a non-zero exit code if at least one update is available):

```
$ configlet sync --docs
```

To interactively update the docs for every Practice Exercise, add the `--update` option (or `-u` for short):

```
$ configlet sync --docs --update
```

To non-interactively update the docs for every Practice Exercise, add the `--yes` option (or `-y` for short):

```
$ configlet sync --docs --update --yes
```

To non-interactively update the docs for a single Practice Exercise, use the `--exercise` option (or `-e` for short). For example:

```
$ configlet sync --docs -uy -e prime-factors
```

### Metadata

Every exercise on a track must have a `.meta/config.json` file.
For a Practice Exercise that is derived from the `problem-specifications` repo, this file should contain the `blurb`, `source` and `source_url` key/value pairs that exist in the corresponding upstream `metadata.toml` file.

To check every Practice Exercise for available metadata updates (exiting with a non-zero exit code if at least one update is available):

```
$ configlet sync --metadata
```

To interactively update the metadata for every Practice Exercise, add the `--update` option (or `-u` for short):

```
$ configlet sync --metadata --update
```

To non-interactively update the metadata for every Practice Exercise, add the `--yes` option (or `-y` for short):

```
$ configlet sync --metadata --update --yes
```

To non-interactively update the metadata for a single Practice Exercise, use the `--exercise` option (or `-e` for short). For example:

```
$ configlet sync --metadata -uy -e prime-factors
```

### Tests

If a track implements an exercise for which test data exists in the [problem-specifications repo](https://github.com/exercism/problem-specifications), the exercise _must_ contain a `.meta/tests.toml` file. The goal of the `tests.toml` file is to keep track of which tests are implemented by the exercise. Tests in this file are identified by their UUID and each test has a boolean value that indicates if it is implemented by that exercise.

A `tests.toml` file has this format:

```toml
# This is an auto-generated file.
#
# Regenerating this file via `configlet sync` will:
# - Recreate every `description` key/value pair
# - Recreate every `reimplements` key/value pair, where they exist in problem-specifications
# - Remove any `include = true` key/value pair (an omitted `include` key implies inclusion)
# - Preserve any other key/value pair
#
# As user-added comments (using the # character) will be removed when this file
# is regenerated, comments can be added via a `comment` key.

[1e22cceb-c5e4-4562-9afe-aef07ad1eaf4]
description = "basic"

[79ae3889-a5c0-4b01-baf0-232d31180c08]
description = "lowercase words"

[ec7000a7-3931-4a17-890e-33ca2073a548]
description = "invalid input"
include = false
comment = "excluded because we don't want to add error handling to the exercise"
```

In this case, the track has chosen to implement two of the three available tests. If a track uses a _test generator_ to generate an exercise's test suite, it _must_ use the contents of the `tests.toml` file to determine which tests to include in the generated test suite.

To check every Practice Exercise `tests.toml` file for available tests updates (exiting with a non-zero exit code if there is at least one test case that appears in the exercise's canonical data, but not in the `tests.toml`):

```
$ configlet sync --tests
```

To interactively update the `tests.toml` file for every Practice Exercise, add the `--update` option:

```
$ configlet sync --tests --update
```

For each missing test, this prompts the user to choose whether to include/exclude/skip it, and updates the corresponding `tests.toml` file accordingly.
Configlet writes an exercise's `tests.toml` file when the user has finished making choices for that exercise.
This means that you can terminate configlet at a prompt (for example, by pressing Ctrl-C in the terminal) and only lose the syncing decisions for at most one exercise.

To non-interactively include every unseen test case, use `--tests include`. For example, to do so for an exercise named `prime-factors`:

```
$ configlet sync --tests include -u -e prime-factors
```

Remember to actually implement these tests on the track!

### Filepaths

Finally, the `sync` command also handles "syncing" from a source that isn't `problem-specifications` - the track-level `config.json` file.
Every Concept Exercise and Practice Exercise must have a `.meta/config.json` file with a `files` object that specifies the (relative) locations of the files that the exercise uses.
Such filepaths usually follow a simple pattern, and so configlet can populate the exercise-level values from patterns in the `files` key of the track-level `config.json` file.

To check that every Concept Exercise and Practice Exercise on the track has a fully populated `files` key (or at least one that cannot be populated from the track-level `files` key):

```
$ configlet sync --filepaths
```

(Note that `configlet lint` will also produce an error when an exercise has a missing/empty `files` key.)

To populate empty/missing values of the exercise-level `files` key for every Concept Exercise and Practice Exercise from the patterns in the track-level `files` key:

```
$ configlet sync --filepaths --update
```

To do this non-interactively and for a single exercise named `prime-factors`:

```
$ configlet sync --filepaths -uy -e prime-factors
```

### Using `sync` when adding a new exercise to a track

The `sync` command is useful when adding a new exercise to a track. If you are adding a Practice Exercise named `foo` that exists in `problem-specifications`, one possible workflow is:
1. Manually add an entry to the track-level `config.json` file for the exercise `foo`. This makes the exercise visible to `configlet sync`.
1. Run `configlet sync --docs --filepaths --metadata -uy -e foo` to create the exercise's documentation, and a starter `.meta/config.json` file with populated `files`, `blurb`, and perhaps `source` and `source_url` values.
1. Edit the exercise `.meta/config.json` file as desired. For example, add yourself to the `authors` array.
1. Run `configlet sync --tests include -u -e foo` to create a `.meta/tests.toml` file with every test included.
1. View that `.meta/tests.toml` file, and add `include = false` to any test case that the exercise will not implement.
1. Implement the tests for the exercise to match those included in `.meta/tests.toml`.
1. Add the other required files.

## `configlet uuid`

Each exercise and concept has a [UUID](https://en.wikipedia.org/wiki/Universally_unique_identifier), which must only appear once across all of Exercism. It must be a valid version 4 UUID (compliant with RFC 4122) in the canonical textual representation, which means that it must match the below regular expression:

```
^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$
```

You can run `configlet uuid` to output a new, appropriate UUID. There is also the `-n, --num` option for outputting multiple new UUIDs:

```
$ configlet uuid --num 5
3823f890-be49-4700-baac-e19de8fda76f
c12309a2-8bd6-4b9c-a511-e1ee4083f492
26167ad5-fe20-43d4-8b1f-3bbb9618c36e
5df11ac0-e612-4223-b0f8-f6cd2cb15cb1
e42b94bb-9c90-47f2-aebb-03cdbc27bf3b
```

## `configlet generate`

Each concept exercise and concept have an `introduction.md` file. If you want the exercise's introduction to include the concept's introduction verbatim, you can create a `introduction.md.tpl` file to achieve this. This file may use a placeholder to refer to the concept's introduction, so that the information is not duplicated.

Concept placeholders must use the following format:

```
%{concept:<slug>}
```

For example, if the track has a concept named `floating-point-numbers` then an `introduction.md.tpl` file can contain:

```
%{concept:floating-point-numbers}
```

You can run `configlet generate` to generate the exercise's `introduction.md` for any exercise that has an `introduction.md.tpl` file. The generated `introduction.md` is identical to the `introduction.md.tpl`, except that concept placeholders are replaced with the contents of the concept's `introduction.md` file (minus its top-level heading). In the future, `configlet generate` will also increment the level of other headings by 1 (e.g. from `## My Heading` to `### My Heading`), but this is not yet implemented.

## Use in your track

Each track should have a `bin/fetch-configlet` script, and might have a `bin/fetch-configlet.ps1` script too. The first is a bash script, and the second is a PowerShell script.

Running one of these scripts downloads the latest version of configlet to the `bin` directory. You can then use configlet by running `bin/configlet` or `bin/configlet.exe` respectively.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/exercism/configlet.
