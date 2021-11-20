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
  -p, --prob-specs-dir <dir>   Use this `problem-specifications` directory, rather than cloning temporarily
  -o, --offline                Do not check that the directory specified by `-p, --prob-specs-dir` is up to date
  -u, --update                 Update unsynced docs, filepaths, metadata, and tests
  -y, --yes                    Auto-confirm every prompt for updating docs, filepaths, and metadata
      --docs                   Sync Practice Exercise .docs/introduction.md and .docs/instructions.md files
      --filepaths              Populate empty `files` values in Concept/Practice exercise .meta/config.json files
      --metadata               Sync Practice Exercise .meta/config.json metadata values
      --tests [mode]           Sync Practice Exercise .meta/tests.toml files.
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

The `sync` command allows tracks to keep `tests.toml` files up to date. A plain `configlet sync` performs no changes, and just compares the tests specified in the `tests.toml` files against the tests that are defined in the exercise's canonical data - if there are tests defined only in the latter, it prints a summary and exits with a non-zero exit code.

To interactively update the `tests.toml` files, use `configlet sync --update`. For each missing test, this prompts the user to choose whether to include/exclude/skip it, and updates the corresponding `tests.toml` file accordingly.

The `configlet sync` command replaces the functionality of the older `canonical_data_syncer` application.

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
