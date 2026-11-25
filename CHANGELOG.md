# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the project follows [Semantic Versioning](https://semver.org/) once it is released.

## [Unreleased]

### Added
- The `character.identity` extractor (`src/ESOExporter/Extractors/Identity.lua`): race, class,
  gender and alliance ids, level and champion points earned, as raw numbers. Its schema is
  `schema/v1/topics/character.identity.schema.json`, referenced from the envelope by topic id
  (each topic PR adds one file under `topics/`). `/eox save` now stores it. The game calls it
  uses were checked in game (API 101051). Also a scrub script
  (`tools/python/scripts/scrub_export.py`) that turns a real SavedVariables file into a committable
  fixture for `schema/fixtures/real/`, which the Python tests validate; the first real output,
  `identity.lua`, is there.
- Add-on skeleton: the `ESOExporterData` data add-on, which owns the export's SavedVariables
  file and has no code; `ESOExporter.Registry` (an extractor per tree topic, checked at load);
  `ESOExporter.Runner` (runs extractors under `pcall`, stores sanitized entries at their
  schema v1 paths, reports stored, missing and failed topics); and `/esoexport save [ids]`
  with the alias `/eox`. No topic has an extractor yet, so a save writes only `meta`.
  ESOExporter now depends on `LibExportStore` and `ESOExporterData`.
- Topic tree v1 (`schema/v1/tree.json`, `tree.schema.json`): a fresh tree of groups and topics
  with full dotted snake_case ids, `account` or `character` scope and a `light` or `heavy`
  cost, where every node can be switched on or off on its own. Not ported from
  CharacterMarkdown's config. A generated Lua copy (`src/ESOExporter/TopicTreeData.lua`,
  `tools/python/scripts/gen_tree_lua.py`) is what the add-on loads, and a test keeps it current.
- `ESOExporter.TopicTree` (`src/ESOExporter/TopicTree.lua`): pure functions that index and
  validate the tree, derive effective state from overrides with the gate rules, list topics
  by scope or under a group, and compact overrides to the differences from the defaults. The
  add-on folder and manifest now exist but do nothing else yet; presets are deferred to M4.
- The export schema now requires topic keys to be full dotted snake_case paths, and the
  hand-built fixture's topics are renamed to match (`account.currency`, `character.identity`,
  and the synthetic `fixture.long_text` and `fixture.dropped`).
- An `open-pr` project skill for the order of PR bookkeeping, and hygiene checks that the plan's
  pull request rows are well formed (always) and match GitHub (`task hygiene:prs`).
- Design: the shared data models of both post-processors are generated from the schema and
  checked in CI; everything else in a post-processor stays static code. Recorded in the
  architecture (3.4, 11, 13, 14, 15) and the plan (M5, M6, risks, open decisions, roadmap).
- Project scaffold: README, license, contributing guide, issue and PR templates,
  and architecture notes.
- Project plan and a fuller architecture document.
- `LibExportStore` 0.1.0 (provisional name): sanitize and split structured data so
  SavedVariables can hold it, store entries at a path, and summarize what is stored.
- `CLAUDE.md` with the workflow, conventions and pointers an agent session needs.
  The handoff between sessions is the tracked kickoff notes in the project plan.
- Developer tooling: StyLua and Luacheck configuration, a Taskfile, and an
  offline Lua test runner (LuaJIT).
- Schema v1: a JSON Schema for the export envelope (`schema/v1/export.schema.json`), a
  hand-built fixture, and a Python project (`tools/python`, managed with uv; Black, Ruff,
  Pyrefly, pytest) with a safe SavedVariables reader and tests that validate the fixture
  and reject broken copies.
- `main` is protected by one ruleset ("main checks") that requires the CI jobs; the classic
  branch protection is removed.
- CI: a GitHub Actions workflow (PR title check, Lua checks under LuaJIT and Lua 5.1, Python
  checks on Linux, Windows and macOS, repository hygiene), Dependabot for Actions and uv, and a
  hygiene script that blocks personal data, unknown fixture names and malformed manifests.
- The plan's roadmap now has a milestone status table (with what each needs) and pull request
  tables with links: milestone work in milestone order, and housekeeping kept separate.
- Next-step kickoff notes for CI and the topic tree, and a prompt for the next session, in
  the project plan.
- `docs/CI_AND_RELEASES.md`: a draft plan for CI, semver and conventional-commit releases,
  release artifacts and post-processor packaging.
- Development environment guide (`docs/DEVELOPMENT.md`) for working alone or with Claude Code,
  and `tools/dev-setup.sh` (`task setup`): checks every tool, login and per-machine item a
  session needs, and with `--install` puts pinned, checksum-verified StyLua, Task and uv in
  `~/.local/bin` without sudo. The ESO API documentation file is now git-ignored.

### Fixed
- `tools/dev-setup.sh` exited 1 after a successful check (its cleanup trap returned the status
  of a false test), and suggested the `apt`/`brew` command even when only StyLua, Task or uv
  was missing.
