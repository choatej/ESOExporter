# CLAUDE.md

Guidance for Claude Code sessions in this repository. Read this first, then
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) (the design) and
[docs/PROJECT_PLAN.md](docs/PROJECT_PLAN.md) (milestones, PR roadmap, open decisions);
[docs/CI_AND_RELEASES.md](docs/CI_AND_RELEASES.md) is the draft CI and release plan, and
[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) sets up a machine.

## What this is

ESOExporter is an Elder Scrolls Online add-on that extracts character and account
data into nested Lua tables and gets it out through SavedVariables, plus
post-processors that format the data outside the game. It is the maintainer's
independent successor to their CharacterMarkdown fork. It shares no code with
CharacterMarkdown (README credits it as "Inspired By").

## Starting a session

The maintainer starts every session with: *"Read CLAUDE.md, ask the kickoff questions,
then do the next step."* This file is the single entry point; do this:

1. Read this file, then the docs named at the top. Run `gh pr list --state all` and
   check `git log origin/main` so you know what has merged. If an earlier PR is still
   open, stack on it per CONTRIBUTING.md.
2. Ask the questions in "Kickoff notes for the next step" in `docs/PROJECT_PLAN.md`, in
   one batch, each with a recommendation. Do not start before they are answered.
3. Do the work: branch, PR, squash only, no rebase, noreply commit email. Do not merge
   unless asked, and do not change repository settings or secrets unasked.
4. Finish by updating "Where we are" below, the plan's milestone and pull request tables and
   the kickoff notes for the work after it, in the same PR.

On a machine you have not checked yet, run `tools/dev-setup.sh` (check only) and tell the
maintainer what is missing. Do not install anything unasked; `--install` (user-local, no sudo)
and the system packages it prints are the maintainer's call. Setup is in `docs/DEVELOPMENT.md`.

## Where we are

Merged (#1 to #16): scaffold, docs, Lua tooling, `LibExportStore` (the export library),
schema v1 (`schema/v1/export.schema.json`), a hand-built fixture
(`schema/fixtures/hand-built/`), a Python SavedVariables reader and schema tests
(`tools/python`, a uv project with black, ruff, pyrefly and pytest; `task python:check`),
the CI and release plan, and CI (`.github/workflows/ci.yml`; jobs `pr-title`, `lua`,
`python`, `repo-hygiene`; Dependabot), all required on `main`, the model-generator design (#12),
the `open-pr` skill (#13), the topic tree (#14), the add-on skeleton (#15) and the development
setup guide and `tools/dev-setup.sh` (#16). M0 and M1 are done; M2 has one pull request left. Decided with the
maintainer in #7: keep the name `LibExportStore`; export data lives in a separate small data
add-on with its own SavedVariables file; JSON Schema draft 2020-12 validated with Python
`jsonschema`; storage layout as in ARCHITECTURE.md 4.1.
The CI and release plan is `docs/CI_AND_RELEASES.md` (semver from conventional commits
via release-please, release artifacts, post-processor packaging); only the CI workflow is
implemented, and the rest has open decisions for the maintainer.
Decided with the maintainer in the topic tree PR: a fresh tree, nothing ported from
CharacterMarkdown's config; topic ids are full dotted snake_case paths and are the storage
keys; every topic has `scope` and `cost`; every node toggles on its own; **presets are
deferred to M4** (users must be able to pick one and then diverge from it easily). The tree
is `schema/v1/tree.json`; the game loads its generated Lua copy
(`src/ESOExporter/TopicTreeData.lua`, regenerate with `tools/python/scripts/gen_tree_lua.py`)
through `src/ESOExporter/TopicTree.lua`.
Decided with the maintainer in the add-on skeleton PR (#15): the data add-on is
`ESOExporterData` (`src/ESOExporterData/`, no code); API version 101051 only; one slash
command `/esoexport` with the alias `/eox`, and subcommands added only when needed (`save` so
far); extractors register by tree id (`ESOExporter.Register`), and the runner runs them under
`pcall`. The character identity extractor (`src/ESOExporter/Extractors/Identity.lua`, schema in
`schema/v1/topics/`, one file per topic) is written and tested offline with stubbed game calls,
but its game calls are **not yet checked in game** (no API docs were on disk). Decided with the
maintainer there: raw ids and numbers only; scrubbed real output goes in `schema/fixtures/real/`
(`tools/python/scripts/scrub_export.py`) and the hand-built fixture stays for the synthetic
topics. M2 ends when a real SavedVariables file from the game validates.

The next step's questions and scope, and a ready-to-paste prompt for the next session,
are in "Kickoff notes" in the plan. Ask those questions first.

**Decisions that belong to the maintainer. Ask, do not decide silently:**
the export library's final name (`LibExportStore` is provisional, kept for now) and the
default post-processor's technology.

## Session handoff

- **The handoff is tracked, not a separate file.** Where we are is "Where we are"
  in this file; what to do next and what to ask the maintainer first is "Kickoff
  notes" in `docs/PROJECT_PLAN.md`. Update both, and the plan's milestone and pull
  request tables (with the PR number and link), in the PR that finishes the work, and
  write the kickoff notes for what comes after it.
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
  protected by the repository ruleset "main checks" (there is no classic branch
  protection): PR required, 0 approvals, review threads resolved, squash merge only,
  no force-push or deletion, no bypass actors (admins included), and the required status
  checks `pr-title`, `lua`, `repo-hygiene` and the four `python (...)` jobs. Merge
  commits and rebase merges are disabled. **Do not rebase.** Ruleset and branch settings
  are the maintainer's: do not change them unasked. If a CI job is renamed, the ruleset's
  required check names must change with it.
- Do not merge PRs unless the maintainer asks you to.
- **Use the `open-pr` skill** (`.claude/skills/open-pr/`) to open every PR. It has the order
  of the checks, the docs, and the plan row that needs the PR's own number (open, then add
  the row, then push again; `task hygiene:prs` verifies it).
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

Needs Task, LuaJIT, Lua 5.1, Luacheck, StyLua 0.20.0 and [uv](https://docs.astral.sh/uv/);
`tools/dev-setup.sh` checks them and `docs/DEVELOPMENT.md` says how to get them.

```sh
task check     # format check, luacheck, offline tests
task format    # apply StyLua
task test      # Lua tests only; `task test -- export` filters by spec name
task hygiene       # repo hygiene: no personal data, fixture names, manifests
task hygiene:prs   # also compare the plan's PR rows with GitHub (needs a logged-in gh)
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
  project install tasks. It is a personal skill (`~/.claude/skills/`), not in the repo; if it
  is missing, say so and ask before copying by hand (see `docs/DEVELOPMENT.md`).

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
  101050 and `docs/ESOUIDocumentation.txt` (git-ignored) for 101048. Both are older than the
  live 101051, so confirm any function or constant in game before relying on it. Either may
  be missing on a new machine; `docs/DEVELOPMENT.md` says where they come from.
- The upstream-PR hold on CharacterMarkdown is a separate matter and does not
  affect this repository.

## Verified and assumed

Verified (see ARCHITECTURE.md): the game silently drops saved strings of 2000
characters or more (ZOS staff, 2020); the live API version above. Everything
marked *(verify)* in the docs is an assumption to confirm in game before relying on it.
