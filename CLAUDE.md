# CLAUDE.md

Guidance for Claude Code sessions in this repository. Read this first, then
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) (the design) and
[docs/PROJECT_PLAN.md](docs/PROJECT_PLAN.md) (milestones, PR roadmap, open decisions);
[docs/CI_AND_RELEASES.md](docs/CI_AND_RELEASES.md) is the draft CI and release plan.

## What this is

ESOExporter is an Elder Scrolls Online add-on that extracts character and account
data into nested Lua tables and gets it out through SavedVariables, plus
post-processors that format the data outside the game. It is the maintainer's
independent successor to their CharacterMarkdown fork. It shares no code with
CharacterMarkdown (README credits it as "Inspired By").

## Where we are

Merged: scaffold, docs, Lua tooling, `LibExportStore` (the export library).
In review: schema v1 (`schema/v1/export.schema.json`), a hand-built fixture
(`schema/fixtures/hand-built/`), a Python SavedVariables reader and schema tests
(`tools/python`, a uv project with black, ruff, pyrefly and pytest; `task python:check`).
Decided with the maintainer in step 6: keep the name `LibExportStore`; export data
lives in a separate small data add-on (provisionally `ESOExporterData`) with its own
SavedVariables file; JSON Schema draft 2020-12 validated with Python `jsonschema`;
storage layout as in ARCHITECTURE.md 4.1.
Next, in order (see the PR roadmap in the plan): topic tree v1, add-on skeleton with
topic registry and runner, character identity extractor and `save` command. Until the
add-on exists there is no real output, so the fixture is hand-built to the schema.

The next step's questions and scope are in "Kickoff notes" in the plan. Ask those
questions first.

**Decisions that belong to the maintainer. Ask, do not decide silently:**
the export library's final name (`LibExportStore` is provisional, kept for now), the
data add-on's name (`ESOExporterData` is provisional), the
default post-processor's technology and slash
command names.

## Session handoff

- **The handoff is tracked, not a separate file.** Where we are is "Where we are"
  in this file; what to do next and what to ask the maintainer first is "Kickoff
  notes" in `docs/PROJECT_PLAN.md`. Update both, and the plan's step table, in the
  PR that finishes a step, and write the kickoff notes for the step after it.
  There is no handoff file to look for.
- **Private notes are optional.** Anything personal or machine-specific can go in
  `.local/`, which is git-ignored. It may not exist; do not treat that as a problem.
  Ignored files are per checkout, so a session in a git worktree does not have its
  own copy and loses anything it writes there when the worktree is removed. Use the
  **primary checkout's** directory by absolute path, `~/src/ESOExporter/.local/`,
  and read whatever is there. A background (worktree-isolated) session can read that
  directory but the harness refuses its writes there, so it puts anything the
  maintainer should keep in its final report.

## Git workflow (strict)

- Never commit or push to `main`. Branch, open a PR, squash-merge. `main` is
  protected: PR required, 0 approvals, admins included, linear history. Merge
  commits and rebase merges are disabled. **Do not rebase.**
- Do not merge PRs unless the maintainer asks you to.
- PR titles are Conventional Commits (`feat(addon): ...`); the title becomes the
  squash commit. Branch prefixes: `feat/ fix/ docs/ chore/ refactor/ test/`.
- Stacked PRs are fine; follow the procedure in CONTRIBUTING.md exactly (it
  conflicts on files the child changed after the parent added them, and the fix
  is only safe after checking `main`'s copy equals the parent's).
- Commit with the GitHub noreply address, never the maintainer's personal email:
  `git config user.email 401076+choatej@users.noreply.github.com`.
- Keep docs in the same PR as the change: `ARCHITECTURE.md`, `PROJECT_PLAN.md`
  (PR table), `CHANGELOG.md` under `[Unreleased]`.
- After a merge, sync local `main` (`git pull --ff-only`) and delete the branch.
- Badges and topics: no ESOUI badge or topic until an ESOUI listing exists; CI
  badge only once a workflow exists.

## Commands

Needs Task, LuaJIT, StyLua and Luacheck (installed on the maintainer's machine) and
[uv](https://docs.astral.sh/uv/) for the Python project (`tools/python`; may need installing).

```sh
task check     # format check, luacheck, offline tests
task format    # apply StyLua
task test      # Lua tests only; `task test -- export` filters by spec name
task python:check  # Python (tools/python, a uv project): black, ruff, pyrefly, pytest
task test:python   # Python tests only, including schema validation
lua5.1 tests/lua/run.lua   # also run under stock Lua 5.1, closer to the game
```

Run both LuaJIT and stock `lua5.1` before calling Lua work done: they differ
(for example `coroutine.create` rejects C functions on stock Lua).

## Conventions

- Lua targets ESO's Lua 5.1: no `goto`, no 5.2+ features, 4-space indent, 120 columns.
- Pure code (no game calls) is unit tested offline. Code that touches the game
  needs an in-game check, described in the PR with the game version.
- The add-on emits raw data and never formats: IDs, enums, raw item links,
  `nil` for absent values. Names and display text are resolved in post-processing.
- Every topic is added in its own PR with its schema, fixture and tests.
- Real SavedVariables files and personal data never enter the repo. Fixtures are
  scrubbed. `.gitignore` blocks the obvious paths.
- Manifest folder name must equal the manifest file name. Live API version was
  101051 (game 12.1.7) on 2026-11-14; check the current value before bumping.
- Deploy to the game with the `deploy-eso-addon` skill, not ad hoc copying or
  project install tasks.

## Source material outside this repo

All read-only references. Nothing here is a dependency.

- `~/src/CharacterMarkdown`: the maintainer's fork of upstream CharacterMarkdown
  (MIT; authors solaegis and Lewis Vavasour). Branches holding the maintainer's
  **own** earlier work, to port into this repo through PRs:
  - `feat/cmdata-model`: `tools/cmdata/` Python model of a structured export; the
    22-topic catalog is `TOPICS` in `tools/cmdata/export.py`.
  - `feat/config-tree`: `tools/cmconfig/`, `data/config/tree.json` (the topic tree
    with gate semantics, documented in `data/config/README.md`), and the Lua test framework.
  - `feat/structured-data-export`, `feat/sv-export-converter`: `ExportStore`,
    `/cm save`, and `tools/sv_export.py`.
  Read a file with `git --git-dir=$HOME/src/CharacterMarkdown/.git show <branch>:<path>`.
  Port only code authored by the maintainer (check `git log`), and review it for
  lines derived from upstream. That code encodes upstream's data shapes, so
  redesign them per "Raw data" in ARCHITECTURE.md instead of copying them.
- `~/src/cm-dump-2026-11-14/`: real exports from the maintainer's character,
  including a real `SavedVariables` file. Use them to design fixtures. They
  contain real character and account names, so scrub anything derived from them.
- ESO API reference: `~/src/CharacterMarkdown/ESOUIDocumentationP50.txt` is for API
  101050 and `docs/ESOUIDocumentation.txt` for 101048. Both are older than the
  live 101051, so confirm any function or constant in game before relying on it.
- The upstream-PR hold on CharacterMarkdown is a separate matter and does not
  affect this repository.

## Verified and assumed

Verified (see ARCHITECTURE.md): the game silently drops saved strings of 2000
characters or more (ZOS staff, 2020); the live API version above. Everything
marked *(verify)* in the docs is an assumption to confirm in game before relying on it.
