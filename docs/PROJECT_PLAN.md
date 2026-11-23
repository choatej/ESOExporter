# Project plan

Status: **draft.** This is the delivery order, not a schedule: no dates, because
the work is done at the maintainer's pace. How the system fits together is in
[ARCHITECTURE.md](ARCHITECTURE.md). Update this file in the pull request that
completes or changes a step.

## Working agreements

- Everything reaches `main` through a pull request, squash-merged. `main` is
  protected.
- Small pull requests. A pull request that depends on an unmerged one is
  **stacked** on its branch; see "Stacked pull requests" in
  [CONTRIBUTING.md](../CONTRIBUTING.md).
- Every code pull request carries its own tests, and in-game behaviour is
  verified in game and noted in the pull request.
- Real SavedVariables files and personal data never enter the repository. Only
  scrubbed fixtures do.
- Deploy to the game with the dedicated deploy workflow, not by ad hoc copying.

## Milestones

Each milestone has an exit condition. A milestone is done when its condition is
met and its pull requests are merged.

### M0: Foundation

- Scaffold, license, contribution workflow, issue and PR templates.
- Architecture and plan documents.
- Developer tooling: StyLua, Luacheck, offline Lua test runner, task runner.

*Exit:* `task check` passes locally on a clean checkout.

### M1: Export library and schema v1

- `LibExportStore`: sanitize, split and join, put and remove, summarize, with
  tests (including a property test that no stored string reaches 2000 characters).
- Schema v1: storage envelope, entry shape, `meta`, and the `$parts` convention.
- Topic tree v1 (`tree.json`) with the starting topic catalog.
- A first fixture. It is hand-built to the schema, because no add-on output exists
  yet; it is replaced by scrubbed real output once M2 produces some.

*Exit:* the library passes its tests under LuaJIT, and the schema validates the
fixture.

### M2: Add-on skeleton

- Manifest with the live API version, namespace, safe-call and logging helpers.
- Topic registry and runner.
- First extractor (character identity) and a working `save` command.
- Deployed to the game and verified through a real `/reloadui` round trip.

*Exit:* a real SavedVariables file is produced in game and validates against the
schema.

### M3: First extractors

Character, stats, equipment, skills and skill bars, champion points. Async
extraction under LibAsync. Extractors tested against stubbed game functions and
checked in game.

*Exit:* a real character exports these topics without errors and within a
reasonable time and size.

### M4: Settings and reminders

- In-game settings screen driven by the topic tree, with a default-export preset.
- Saved selection, applied by a no-argument `save`.
- Login reminder about stored exports, and clear.

*Exit:* a user can configure and run an export without typing any command
arguments, on desktop and on Steam Deck.

### M5: Python post-processor

Port the existing Python model and tools, adapt them to schema v1, and test
them against the golden fixtures. Output: normalized JSON and a lean Markdown
view.

*Exit:* the fixture from M2 or M3 converts to the expected outputs.

### M6: Default post-processor

Browser-based, local, no installation. Same fixtures and the same normalized
model as the Python tool.

*Exit:* both post-processors produce identical normalized output for every
fixture.

### M7: Remaining extractors

Inventory, achievements, collectibles, crafting knowledge, antiquities,
progression, currency, quests, housing, guilds, PvP, companions, titles, and
others as the tree grows. Heavy topics stay opt-in. Topics are added one pull
request at a time.

*Exit:* the topic catalog in `tree.json` has an extractor, a schema, a fixture
and a post-processor mapping for each entry.

### M8: First release

- Packaging, versioning and changelog.
- ESOUI listing and a CI release workflow.
- User documentation: install, configure, export, post-process, clear.
- ESOUI topic and badges added to the repository once the listing exists.
- Publish `LibExportStore` once a second consumer exists or the API is stable.

*Exit:* v0.1.0 installable from ESOUI.

## Order and dependencies

- M0, M1, M2, M3 run in that order.
- M4 (settings), M5 (Python), and M7 (remaining extractors) can all start once
  M3 is done. M5 only needs real output from M2 or M3.
- M6 (default post-processor) follows M5, because it reuses its fixtures and model.
- M8 (release) needs M4, M6 and enough of M7 to be useful.

## Pull request roadmap

| # | Branch | Title | Milestone | State |
|---|---|---|---|---|
| 1 | `chore/scaffold` | Project scaffold and architecture notes | M0 | merged |
| 2 | `docs/architecture-and-plan` | Architecture and project plan | M0 | merged |
| 3 | `chore/dev-tooling` | Lua tooling and offline test runner | M0 | merged |
| 4 | `feat/export-lib` | `LibExportStore` | M1 | merged |
| 5 | `docs/agent-context` | `CLAUDE.md` for agent sessions; update this table | M0 | open |
| 6 | | Schema v1 and first fixture | M1 | planned |
| 7 | | Topic tree v1 | M1 | planned |
| 8 | | Add-on skeleton, topic registry and runner | M2 | planned |
| 9 | | Character identity extractor and `save` command | M2 | planned |

Later pull requests are added here as earlier ones merge.

### Kickoff notes for the next step (PR 6: schema v1 and a first fixture)

Replace this section when the PR merges. Before writing anything, ask the
maintainer these questions in one batch, each with a recommendation:

1. **Library name.** `LibExportStore` is provisional.
2. **One add-on or two.** SavedVariables are written to one file per add-on holding
   every global it lists *(verify)*. A small separate data add-on gives exports their
   own file, so a user can clear them by deleting it without losing settings.
   Recommendation: separate.
3. **Schema validation.** The Lua toolchain has no JSON Schema validator, so choose
   a Python test dependency or a small hand-written checker.
4. **Storage layout.** Confirm or change the draft in ARCHITECTURE.md section 4.1
   (account scope, characters keyed by character id, entry shape).

Then build: a `schema/` directory with the envelope and entry schemas and the
`$parts` convention from `LibExportStore`; a fixture hand-built to the schema (no
add-on output exists yet); and a test that validates it. Update ARCHITECTURE.md,
this table, `CLAUDE.md` "Where we are", and the changelog in the same PR.

The step after is PR 7, the topic tree, starting from `data/config/tree.json` on
the maintainer's fork branch `feat/config-tree` (see `CLAUDE.md`).

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| SavedVariables size or load time grows with exports | Report size, opt-in heavy topics, login reminder, clear command |
| Game updates change API results | Raw storage, `meta` records versions, per-extractor error isolation |
| Two post-processors drift apart | Shared schema, shared golden fixtures, identical-output test |
| LibAddonMenu cannot express the topic tree | Fall back to a small custom panel; decide in M4 |
| Dependency libraries break or go stale | Optional dependencies with fallbacks; check update history before adopting |
| Personal data leaks through fixtures or reports | Scrubbed fixtures only; `.gitignore` rules; redaction option |
| Scope creep across topics | One topic per pull request, each with schema, fixture and tests |

## Open decisions

1. Name of the export library (currently `LibExportStore`).
2. Whether export data lives in a separate small add-on to get its own file.
3. Technology and distribution of the default post-processor.
4. Schema language details (JSON Schema draft) and how schemas are validated: the
   Lua toolchain has no JSON Schema validator, so validation needs a Python test
   dependency or a small hand-written checker.
5. Slash command names.

## Assumptions to verify in game

- All globals listed in an add-on's `## SavedVariables` are written to one file
  named after the add-on.
- The event used for the login reminder fires once per session at a point where
  chat output is visible.
- Character ids are stable and unique per account and server.
- LibAddonMenu submenus nest deeply enough for the topic tree.

## Appendix: library survey (2026-11-21)

Read from the ESOUI Libraries category (newest four pages of eight) and the file
pages of the libraries below. Versions and dates are as shown on ESOUI.

| Library | Version, updated | Verdict |
|---|---|---|
| LibAsync | 3.1.6, 2026-11-15 | Use |
| LibCharacterKnowledge | 3.1.4, 2026-11-20 | Use at export time only |
| LibItemSets | 1.0.1, 2026-08-27 | Optional |
| LibAddonMenu-2.0 | 2026-05-12 | Use for settings |
| LibSets | 0.9.4, 2026-09-28 | Skip at runtime; set data resolved outside the game |
| LibSavedVars | 6.1.1, 2026-09-28 | Skip; login errors reported after the last update |
| LibSlashCommander | last seen 2020 | Skip |
| LibSetDetection, LibSkillsFactory, LibItemLinkDecoder | various | Skip |

No existing library serializes structured data or chunks long strings for
SavedVariables, which is the gap `LibExportStore` fills.
