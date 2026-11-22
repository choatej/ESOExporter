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

   The child contains the parent's original commits and `main` has the squashed
   version of the same content, so the merge is normally clean. If you changed
   the parent after opening the child, resolve any conflict in favour of `main`'s
   copy of the parent's files.
3. Check the child's diff now shows only its own changes, then squash-merge it.

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

- **Lua** targets ESO's Lua 5.1: no `goto`, no 5.2+ features. Formatting is
  [StyLua](https://github.com/JohnnyMorganz/StyLua) (`stylua.toml`) and linting is
  [Luacheck](https://github.com/lunarmodules/luacheck) (`.luacheckrc`).
- **Python** is formatted and linted with Ruff.
- Add-ons cannot write files, and a SavedVariables string must stay under 2000
  characters; keep both in mind when touching storage code.

## Tests

You need [Task](https://taskfile.dev), LuaJIT, StyLua and Luacheck on your path.

```sh
task check    # formatting, lint and the offline Lua tests
task format   # apply formatting
task test     # tests only; see tests/README.md
```

CI will run `task check` later. For behaviour that cannot be tested offline,
describe how you verified it in game and which game version you used.

## Reporting bugs

Open an issue with the template. Include the add-on version and the game's API
version (`/script d(GetAPIVersion())`). Do not paste SavedVariables files that
contain personal data.

## Licensing

By contributing you agree your contribution is licensed under the
[MIT License](LICENSE).
