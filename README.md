# Configlet for Exercism v3

This is a development version of Configlet for use with v3 of Exercism.

It includes a `sync` command to help Exercism tracks keep their exercise-specific `tests.toml` files in sync with the latest canonical data in the [problem-specifications repo](https://github.com/exercism/problem-specifications).

## Usage

The application is a single binary and can be used as follows:

```
Usage:
  configlet_v3 [global-options] <command> [command-options]

Commands:
  sync

Options for sync:
  -e, --exercise <slug>        Only sync this exercise
  -c, --check                  Terminates with a non-zero exit code if one or more tests are missing. Doesn't update the tests
  -m, --mode <mode>            What to do with missing test cases. Allowed values: c[hoose], i[nclude], e[xclude]
  -p, --prob-specs-dir <dir>   Use this `problem-specifications` directory, rather than cloning temporarily
  -o, --offline                Do not check that the directory specified by `-p, --prob-specs-dir` is up-to-date

Global options:
  -h, --help                   Show this help message and exit
      --version                Show this tool's version information and exit
  -v, --verbosity <verbosity>  The verbosity of output. Allowed values: q[uiet], n[ormal], d[etailed]
```

Running the `sync` command will prompt the user to choose whether to include or exclude missing tests. It will update the `tests.toml` file accordingly. If you only want a quick check, you can use the `--check` option.

## Use in your track

To use the application in your track, you can copy the [`scripts/fetch-configlet_v3`](./scripts/fetch-configlet_v3) and/or [`scripts/fetch-configlet_v3.ps1`](./scripts/fetch-configlet_v3.ps1) files to your track's repository. Running either of these scripts will download the latest version of the `configlet_v3` tool to your track's `bin` directory.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/exercism/configlet-v3.
