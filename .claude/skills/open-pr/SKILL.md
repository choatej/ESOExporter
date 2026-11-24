---
name: open-pr
description: Open a pull request for ESOExporter work, including every bookkeeping step the project requires (checks, changelog, plan rows, handoff docs, and the second push that adds the PR's own number). Use whenever you are about to commit, push or open a PR in this repository, or when asked to "open a PR", "ship this" or "finish the step".
---

# Open a pull request (ESOExporter)

The rules behind this are in `CLAUDE.md` ("Git workflow") and `CONTRIBUTING.md`. This skill is the
order to do them in. The part that gets forgotten is the plan row, because the PR number does not
exist until the PR is opened: **open the PR, then add its row, then push again.**

Never commit or push to `main`, never rebase, never merge unless asked, never change repository
settings or secrets.

## 1. Before committing

1. **Branch from current `origin/main`** (`git fetch`, then branch; fast-forward only). Prefixes:
   `feat/ fix/ docs/ chore/ refactor/ test/ ci/`. If the work depends on an open PR, stack on it
   as `CONTRIBUTING.md` describes.
2. `git config user.email 401076+choatej@users.noreply.github.com` (never the personal address).
3. **Run the checks that apply**, and fix what they report:
   - always: `task hygiene`
   - Lua changed: `task check` **and** `lua5.1 tests/lua/run.lua` (they differ)
   - Python changed: `task python:check`
   - code that touches the game: describe the in-game check and the game version in the PR body
4. **Update the docs in the same PR** (skip a file only if it truly does not apply):
   - `CHANGELOG.md` under `[Unreleased]`
   - `docs/ARCHITECTURE.md` if the design changed
   - `docs/PROJECT_PLAN.md`: milestone status table, and the pull request tables
   - if this PR finishes a step: `CLAUDE.md` "Where we are" and the plan's "Kickoff notes" for the
     step after it

## 2. Commit and open

5. Commit with a Conventional Commit message ending with the co-author trailer from the session
   instructions. The **PR title** is a Conventional Commit too (`feat(addon): ...`); it becomes the
   squash commit and the `pr-title` check enforces it.
6. Push with `-u` and open the PR with `gh pr create`. The body says what and why, how it was
   checked, any "stacked on #N", and ends with the attribution line from the session instructions.

## 3. After opening: the PR's own row

7. Add this PR's row to `docs/PROJECT_PLAN.md` with its number and link:
   - milestone work: replace its `planned` row in the milestone table, state `open`
   - housekeeping: add a row to the housekeeping table, state `open`

   Also **fix any row that is stale** (a PR that merged since the last edit still says `open`).
8. Run `task hygiene:prs`. It compares the plan's rows with GitHub and lists stale states and PRs
   with no row. Fix what it reports.
9. Commit (`docs(plan): ...`) and push to the same branch. Do not open a second PR for this.
10. Report the PR link, what was checked, and anything the maintainer must do (merge, settings).

## After the maintainer merges

`git switch main && git pull --ff-only`, delete the branch. The merged PR's row says `merged`; the
next PR's step 7 fixes it if it still says `open`.
