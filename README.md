# Exercism Canonical Data Syncer

This small application is used to help Exercism tracks keep their exercise-specific `tests.toml` files in sync with the latest canonical data in the [problem-specifications repo](https://github.com/exercism/problem-specifications).

## Goal

If a track implements an exercise for which test data exists, the exercise _must_ contain a `.meta/tests.toml` file. The goal of the `tests.toml` file is to keep track of which tests are implemented by the exercise. Tests in this file are identified by their UUID and each test has a boolean value that indicates if it is implemented by that exercise.

A `tests.toml` file for a track's `two-fer` exercise looks like this:

```toml
[canonical-tests]
# no name given
"19709124-b82e-4e86-a722-9e5c5ebf3952" = true
# a name given
"3451eebd-123f-4256-b667-7b109affce32" = true
# another name given
"653611c6-be9f-4935-ab42-978e25fe9a10" = false
```

In this case, the track has chosen to implement two of the three available tests. If a track uses a _test generator_ to generate an exercise's test suite, it _must_ use the contents of the `tests.toml` file to determine which tests to include in the generated test suite. 

The Canonical Data Syncer application allows tracks to keep `tests.toml` files up to date. When run, the Canonical Data Syncer will compare the tests specified in the `tests.toml` files against the tests that are defined in the exercise's canonical data. It then interactively gives the maintainer the option to include or exclude test cases that are currently missing, updating the `tests.toml` file accordingly.

## Usage

The application is a single binary and can be used as follows:

```
Usage: canonical_data_syncer [options]

Options:
  -e, --exercise <slug>        Only sync this exercise
  -c, --check                  Terminates with a non-zero exit code if one or more tests are missing. Doesn't update the tests
  -m, --mode <mode>            What to do with missing test cases. Allowed values: c[hoose], i[nclude], e[xclude]
  -v, --verbosity <verbosity>  The verbosity of output. Allowed values: q[uiet], n[ormal], d[etailed]
  -p, --prob-specs-dir <dir>   Use this `problem-specifications` directory, rather than cloning temporarily
  -o, --offline                Do not check that the directory specified by `-p, --prob-specs-dir` is up-to-date
  -h, --help                   Show this help message and exit
      --version                Show this tool's version information and exit
```

Running the application will prompt the user to choose whether to include or exclude missing tests. It will update the `tests.toml` file accordingly. If you only want a quick check, you can use the `--check` option.

## Use in your track

To use the application in your track, you can copy the [`scripts/fetch-canonical_data_syncer`](./scripts/fetch-canonical_data_syncer) and/or [`scripts/fetch-canonical_data_syncer.ps1`](./scripts/fetch-canonical_data_syncer.ps1) files to your track's repository. Running either of these scripts will download the latest version of the `canonical_data_syncer` tool to your track's `bin` directory.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/exercism/canonical-data-syncer.
