# .github

Shared GitHub configuration for my repositories. Personal accounts have no account-wide rulesets, so this repository holds one ruleset definition and a script that applies it to every public, non-archived source repository.

Because this repository is public and named `.github`, it can also hold default community health files (`CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, issue and pull request templates) that GitHub shows for any public repository that lacks its own.

## The ruleset

[`rulesets/default-branch.json`](rulesets/default-branch.json) targets each repository's default branch:

- Changes go through a pull request, so CI runs on them, but no approval is required. A new push dismisses earlier approvals, and every review thread must be resolved before merging.
- Pull requests merge by squash only, and the history stays linear.
- The branch cannot be force-pushed or deleted.
- Repository admins can always bypass the rules. That lets me push directly in an emergency.

## Required status checks

CI check names differ from one repository to the next, so they are not part of the shared ruleset. To require checks on a repository, add `checks/<repository>.json` holding a list of check names, exactly as they appear on a pull request (the job name, or `name` if the job sets one):

```json
["test", "clippy", "fmt"]
```

The script then adds a `required_status_checks` rule for that repository. Repositories without a file get no required checks. Only list checks that run on every pull request: a check skipped by a path filter never reports, which blocks the merge.

## Applying

Requires `gh` (logged in with the `repo` scope) and `jq`.

```sh
./apply.sh --dry-run           # show what would change
./apply.sh                     # apply to all public, non-archived source repositories
./apply.sh audio-stack-rs      # apply to the named repositories only
```

The script is idempotent: it finds the ruleset by name and updates it, or creates it if it is missing. Run it again after editing the ruleset, adding a checks file, or creating a repository.

To remove the ruleset from a repository, delete it under Settings → Rules → Rulesets, or with `gh api --method DELETE repos/obazin/<repository>/rulesets/<id>`.
