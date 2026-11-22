# Contributing to ESOExporter

Thanks for your interest. The project is pre-alpha, so the best first step is to
open an issue to discuss what you want to change.

## Workflow

`main` is protected: nothing is committed to it directly.

1. Branch from an up-to-date `main`, using a short prefix:
   `feat/…`, `fix/…`, `docs/…`, `chore/…`, `refactor/…`, `test/…`.
2. Commit in small steps. Messages follow
   [Conventional Commits](https://www.conventionalcommits.org/)
   (`feat(addon): add topic selection`).
3. Push the branch and open a pull request against `main`. Fill in the template.
4. Merge with **squash** only. Merge commits and rebase merges are disabled, so
   the PR title and description become the commit on `main`. Write the title as
   a Conventional Commit.
5. Branches are deleted after merge. Update your local copy:

   ```sh
   git switch main
   git pull          # fast-forward only
   git branch -d <branch>
   ```

## Stacked pull requests

When a change depends on an open pull request, branch from that pull request's
branch and open the new pull request **against the parent branch**, not `main`.
Say "stacked on #N" in the description. Merge in order, parent first:

1. Squash-merge the parent. GitHub deletes its branch and retargets the child to `main`.
2. In the child branch, merge `main` (no rebase) and push:

   ```sh
   git fetch
   git merge origin/main
   git push
   ```

   Expect conflicts in any file the child changed after the parent added it. Git
   sees the parent's squashed copy on `main` and the child's copy (the parent's
   content plus the child's edits) as two different additions. The child's copy
   is the right one, **provided `main`'s copy is exactly what the parent
   contained**, meaning the parent was not changed during review. Check that
   first, then keep the child's files:

   ```sh
   git diff <parent-branch-tip> origin/main --stat   # must print nothing
   git checkout --ours -- <conflicted files>
   git add <conflicted files>
   git commit
   ```

   If the diff is not empty, the parent changed after the child was created, and
   keeping the child's files would discard those changes. Merge them by hand instead.
3. Check that `git diff origin/main --stat` lists only the child's own changes,
   then squash-merge it.

## Repository layout (planned)

```
src/<AddOn>/       the add-on (folder name must match its manifest name)
src/<Lib>/         the export library (own manifest, IsLibrary)
schema/            the versioned data contract and golden fixtures
tools/python/      Python post-processor
tools/web/         default post-processor
docs/              design notes
```

Directories appear as the corresponding pull requests land.

## Code style

- **Lua** targets ESO's Lua 5.1: no `goto`, no 5.2+ features. Formatting with
  StyLua and linting with Luacheck (configuration will be added with the first Lua code).
- **Python** is formatted and linted with Ruff.
- Add-ons cannot write files, and a SavedVariables string must stay under 2000
  characters; keep both in mind when touching storage code.

## Tests

Test and CI setup will be added with the first code. Until then, describe how
you verified a change in the pull request. For in-game behaviour, say which
game version you tested on.

## Reporting bugs

Open an issue with the template. Include the add-on version and the game's API
version (`/script d(GetAPIVersion())`). Do not paste SavedVariables files that
contain personal data.

## Licensing

By contributing you agree your contribution is licensed under the
[MIT License](LICENSE).
