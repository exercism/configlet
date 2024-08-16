# Configlet releases

## How to create a configlet release

1. Check that the repository state is such that creating a release PR makes sense.

1. Run [`bin/bump_version.nim`][bump_version], which also prompts to create a release PR if you have [`gh`][gh] installed on your machine.

1. Ideally, check that `configlet lint` and `configlet sync` don't produce unexpected output on any track - diffing the output from the previous release.

1. Double-check that the repository is in a state such that a release makes sense.
   Remember that we don't support force-pushing to `main`, so any release commit (and tag) remains permanently.

1. If we merged a commit since creating the release PR, rebase the release PR on `main`.
   This ensures that CI tests the merge immediately before the release.

1. Merge the release PR (using "Squash and merge" with the pre-filled commit title and a blank commit body).

1. Run [`bin/tag_release.nim`][tag_release] to tag the release commit and push the tag (which triggers the build job and creates a draft release).

1. Follow the steps that `bin/tag_release.nim` prints as it finishes:

> Remaining steps to release:
>
> 1. Edit the release notes to contain the list of user-facing changes,
>    separating by features and bug fixes.
> 2. Wait for every build job to finish.
> 3. Check that CI is green.
> 4. Un-draft the release.

where un-drafting the release means that, from that moment on, it's used in any newly triggered track CI configlet job (and downloaded by a user who runs `fetch-configlet`).

If you edit the draft release notes in the GitHub web interface, be careful to not prematurely press the green "Publish release" button when you mean to press the "Save draft" button.
You can also edit the release notes using the [GitHub CLI][gh] - for example, for a version `1.2.3`:

```sh
gh -R exercism/configlet release edit 1.2.3 --notes-file /path/to/release_notes.md
```

The release can also be un-drafted using the CLI with, for example:

```sh
gh -R exercism/configlet release edit 1.2.3 --draft=false
```

## Handle problems with a release

### Intermittent failures

If any build job fails due to intermittent failures, we should restart only the failing job.
If we restart a build job that was successful, it will fail when it can't upload an asset that already exists.
In that case, we should manually delete the corresponding asset from the release and then restart the job.

### Cancel or remove a release

If any of these are true:

- A build job fails due to a genuine problem in the configlet codebase.

- We no longer want to create a release at this time.

- We've already published a release, but we want to make track CI use the previous configlet version.

We should:

1. Delete the problematic release, preferably without un-drafting it.
   Don't delete the problematic tag.

1. Create PRs to fix the problem.

1. Merge those PRs.

1. When appropriate, begin the release process again.

1. State in the new release notes that the reader shouldn't use the previous **tag**.

This process means that we don't tag a different commit with a previously pushed tag.
See the [Git documentation on re-tagging][git-re-tag].

### Investigate problems in a release

If we've already published a release, and want to investigate a problem in it, we should mark the release as a prerelease.
Similar to a draft release, a release marked as a prerelease won't be downloaded by a configlet CI job, or `fetch-configlet`.
Note that you can't set a published release as a draft again.
If it turns out that we want the release to be available again, just undo the marking of the release as prerelease.
If it turns out that we want to remove the release, follow the steps in the earlier section to create a new release.

[bump_version]: https://github.com/exercism/configlet/blob/main/bin/bump_version.nim
[gh]: https://github.com/cli/cli
[git-re-tag]: https://git-scm.com/docs/git-tag#_on_re_tagging
[tag_release]: https://github.com/exercism/configlet/blob/main/bin/tag_release.nim
