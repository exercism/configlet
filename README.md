# Configlet for Exercism v3

This is a development version of Configlet for use with v3 of Exercism.

## Usage

The application is a single binary and can be used as follows:

```
Usage:
  configlet [global-options] <command> [command-options]

Commands:
  lint, sync, uuid, generate

Options for sync:
  -e, --exercise <slug>        Only sync this exercise
  -c, --check                  Terminates with a non-zero exit code if one or more tests are missing. Doesn't update the tests
  -m, --mode <mode>            What to do with missing test cases. Allowed values: c[hoose], i[nclude], e[xclude]
  -p, --prob-specs-dir <dir>   Use this `problem-specifications` directory, rather than cloning temporarily
  -o, --offline                Do not check that the directory specified by `-p, --prob-specs-dir` is up-to-date

Options for uuid:
  -n, --num <int>              Number of UUIDs to generate

Global options:
  -h, --help                   Show this help message and exit
      --version                Show this tool's version information and exit
  -t, --track-dir <dir>        Specify a track directory to use instead of the current directory
  -v, --verbosity <verbosity>  The verbosity of output. Allowed values: q[uiet], n[ormal], d[etailed]
```

## Linting

The primary function of configlet is to do _linting_: checking if a track's configuration files are properly structured - both syntactically and semantically. Misconfigured tracks may not sync correctly, may look wrong on the website, or may present a suboptimal user experience, so configlet's guards play an important part in maintaining the integrity of Exercism.

The `configlet lint` command is still under development. The list of currently implemented checks can be found [here](https://github.com/exercism/configlet/issues/249).


## Sync

If a track implements an exercise for which test data exists in the [problem-specifications repo](https://github.com/exercism/problem-specifications), the exercise _must_ contain a `.meta/tests.toml` file. The goal of the `tests.toml` file is to keep track of which tests are implemented by the exercise. Tests in this file are identified by their UUID and each test has a boolean value that indicates if it is implemented by that exercise.

A `tests.toml` file has this format:

```toml
# This is an auto-generated file.
#
# Regenerating this file will:
# - Update the `description` property
# - Update the `reimplements` property
# - Remove `include = true` properties
# - Preserve any other properties
#
# As regular comments will be removed when this file is regenerated, comments
# can be added in a "comment" key

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

The `configlet sync` command allows tracks to keep `tests.toml` files up to date. The command will compare the tests specified in the `tests.toml` files against the tests that are defined in the exercise's canonical data. It will then prompt the user to choose whether to include or exclude missing tests, and update the `tests.toml` files accordingly. If you only want a quick check, you can use the `--check` option.

The `configlet sync` command replaces the functionality of the older `canonical_data_syncer` application.

## Use in your track

Each track should have a `bin/fetch-configlet` script, and might have a `bin/fetch-configlet.ps1` script too. The first is a bash script, and the second is a PowerShell script.

Running one of these scripts downloads the latest version of configlet to the `bin` directory. You can then use configlet by running `bin/configlet` or `bin/configlet.exe` respectively.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/exercism/configlet.
