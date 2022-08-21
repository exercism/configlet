# Notes on configlet releases

## How to create a configlet release

1. Check that the repo state is such that creating a release PR makes sense.

1. Run [`bin/bump_version.nim`][bump_version], which also prompts to create
   a release PR if you have [`gh`][gh] installed on your machine.

1. Ideally, check that `configlet lint` and `configlet sync` do not produce
   unexpected output on any track - diffing the output from the previous
   release.

1. Double-check that the repo is in a state such that a release makes sense.

1. If any commit has been merged since the release PR was created, rebase the
   release PR on `main`. This ensures that CI tests the merge immediately before
   the release.

1. Merge the release PR (using "Squash and merge" with the pre-filled
   commit title and a blank commit body).

1. Run [`bin/tag_release.nim`][tag_release] to tag the release commit and push
   the tag (which triggers the build job and creates a draft release).

1. Follow the steps that `bin/tag_release.nim` prints as it finishes:

> Remaining steps to release:
>
> 1. Edit the release notes to contain the list of user-facing changes,
>    separating by features and bug fixes.
> 2. Wait for every build job to finish.
> 3. Check that CI is green.
> 4. Un-draft the release.

where un-drafting the release means that, from that moment on, it is used in any
newly triggered track CI configlet job (and downloaded by a user who runs
`fetch-configlet`).

If you edit the draft release notes in the GitHub web interface, be careful
to not prematurely press the green "Publish release" button when you mean to
press the "Save draft" button. You can also edit them using the
[GitHub CLI][gh] - for example, for a version `1.2.3`:

```sh
gh -R exercism/configlet release edit 1.2.3 --notes-file /path/to/release_notes.md
```

The release can also be un-drafted using the CLI with, for example:

```sh
gh -R exercism/configlet release edit 1.2.3 --draft=false
```

### Handling problems with a release

If any build job fails due to intermittent issues, you should restart only the
failing job. If you restart a build job that was successful, it will fail when
it cannot upload an asset that already exists (in that case, you should manually
delete the corresponding asset from the release and then restart the job).

If a build job fails due to a genuine problem in the configlet codebase, or you
no longer want to create a release at this time, you can either:

- Delete the draft release, then delete the most recent tag both remotely and
  locally, and then force-push to `main` to remove exactly the most recent
  commit (the release commit)

- Or create a PR to fix the problem, merge it, and then begin the release
  process again. In this case you should not delete the problematic tag, and
  either delete the problematic release without un-drafting it, or keep it as a
  draft and edit its release notes to say that it should not be used.

[bump_version]: https://github.com/exercism/configlet/blob/main/bin/bump_version.nim
[tag_release]: https://github.com/exercism/configlet/blob/main/bin/tag_release.nim
[gh]: https://github.com/cli/cli
