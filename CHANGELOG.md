# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the project follows [Semantic Versioning](https://semver.org/) once it is released.

## [Unreleased]

### Added
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
- CI: a GitHub Actions workflow (PR title check, Lua checks under LuaJIT and Lua 5.1, Python
  checks on Linux, Windows and macOS, repository hygiene), Dependabot for Actions and uv, and a
  hygiene script that blocks personal data, unknown fixture names and malformed manifests.
- The plan's roadmap now has a milestone status table (with what each needs) and pull request
  tables with links: milestone work in milestone order, and housekeeping kept separate.
- Next-step kickoff notes for CI and the topic tree, and a prompt for the next session, in
  the project plan.
- `docs/CI_AND_RELEASES.md`: a draft plan for CI, semver and conventional-commit releases,
  release artifacts and post-processor packaging.
