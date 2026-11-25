# Project plan

Status: **draft.** This is the delivery order, not a schedule: no dates, because
the work is done at the maintainer's pace. How the system fits together is in
[ARCHITECTURE.md](ARCHITECTURE.md). Update this file in the pull request that
completes or changes a row of the pull request roadmap.

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

- In-game settings screen driven by the topic tree, with fine-grained control: every group
  and topic can be switched on or off on its own.
- Presets (named starting points) that a user can pick and then diverge from node by node.
  Their design is deferred to this milestone; see "Presets" in the open decisions.
- Saved selection, applied by a no-argument `save`.
- Login reminder about stored exports, and clear.

*Exit:* a user can configure and run an export without typing any command
arguments, on desktop and on Steam Deck.

### M5: Python post-processor

Port the existing Python tools, adapt them to schema v1, and test them against the
golden fixtures. The shared data models are not ported by hand: this milestone adds the
model generator (schema to typed models, with a CI check that the committed output is
current) and the Python post-processor uses its Python output. Output: normalized JSON
and a lean Markdown view.

*Exit:* the fixture from M2 or M3 converts to the expected outputs, and CI fails if the
generated models are out of date with the schema.

### M6: Default post-processor

Browser-based, local, no installation. Same fixtures and the same normalized
model as the Python tool. Its data models come from the same generator (the target
language follows the technology decision), so only the parser, name resolution and
interface are written by hand.

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

- Packaging, versioning and changelog (see [CI_AND_RELEASES.md](CI_AND_RELEASES.md)).
- ESOUI listing and a CI release workflow.
- User documentation: install, configure, export, post-process, clear.
- ESOUI topic and badges added to the repository once the listing exists.
- Publish `LibExportStore` once a second consumer exists or the API is stable.

*Exit:* v0.1.0 installable from ESOUI.

## Order and dependencies

- M0, M1, M2, M3 run in that order. Housekeeping pull requests (CI, docs, handoff)
  belong to no milestone and can land at any point.
- M4 (settings), M5 (Python), and M7 (remaining extractors) can all start once
  M3 is done. M5 only needs real output from M2 or M3.
- M6 (default post-processor) follows M5, because it reuses its fixtures and model.
- M8 (release) needs M4, M6 and enough of M7 to be useful.

## Pull request roadmap

### Milestone status

Milestones are listed in order. "Needs" is what must be done before the milestone starts;
see "Order and dependencies" above.

| Milestone | Name | Needs | State | Milestone pull requests |
|---|---|---|---|---|
| M0 | Foundation | none | done | [#1](https://github.com/choatej/ESOExporter/pull/1), [#2](https://github.com/choatej/ESOExporter/pull/2), [#3](https://github.com/choatej/ESOExporter/pull/3) |
| M1 | Export library and schema v1 | M0 | done once #14 merges | [#4](https://github.com/choatej/ESOExporter/pull/4), [#7](https://github.com/choatej/ESOExporter/pull/7), [#14](https://github.com/choatej/ESOExporter/pull/14) |
| M2 | Add-on skeleton | M1 | not started | |
| M3 | First extractors | M2 | not started | |
| M4 | Settings and reminders | M3 | not started | |
| M5 | Python post-processor | real output from M2 or M3 | not started | |
| M6 | Default post-processor | M5 | not started | |
| M7 | Remaining extractors | M3 | not started | |
| M8 | First release | M4, M6, enough of M7 | not started | |

M4, M5 and M7 are independent of each other, so their rows below are in milestone
order, not delivery order.

### Pull requests

Every pull request is a row, with a link once it exists. Planned work has no number
until its pull request is opened; the pull request that opens it fills the number in.
Rows for M3 to M8 are an outline and are split or merged when the milestone starts.
A branch name is shown for planned work so it can be found; merged branches are deleted.

**Milestone work**, in milestone order. Rows within a milestone are in delivery order.

| PR | Title | Milestone | State |
|---|---|---|---|
| [#1](https://github.com/choatej/ESOExporter/pull/1) | Project scaffold and architecture notes | M0 | merged |
| [#2](https://github.com/choatej/ESOExporter/pull/2) | Architecture and project plan | M0 | merged |
| [#3](https://github.com/choatej/ESOExporter/pull/3) | Lua tooling and offline test runner | M0 | merged |
| [#4](https://github.com/choatej/ESOExporter/pull/4) | `LibExportStore` | M1 | merged |
| [#7](https://github.com/choatej/ESOExporter/pull/7) | Schema v1, a hand-built fixture, the Python project (uv), and the CI and release plan | M1 | merged |
| [#14](https://github.com/choatej/ESOExporter/pull/14) | Topic tree v1 and gate resolution | M1 | merged |
| [#15](https://github.com/choatej/ESOExporter/pull/15) | Add-on skeleton, data add-on, topic registry and runner | M2 | open |
| planned | Character identity extractor, the first real output (`feat/identity-extractor`) | M2 | planned |
| planned | Async extraction under LibAsync (`feat/async-runner`) | M3 | planned |
| planned | Stats extractor (`feat/topic-stats`) | M3 | planned |
| planned | Equipment extractor (`feat/topic-equipment`) | M3 | planned |
| planned | Skills and skill bars extractor (`feat/topic-skills`) | M3 | planned |
| planned | Champion points extractor (`feat/topic-champion-points`) | M3 | planned |
| planned | Settings screen driven by the topic tree (`feat/settings-panel`) | M4 | planned |
| planned | Saved selection and no-argument `save` (`feat/settings-selection`) | M4 | planned |
| planned | Login reminder and clear (`feat/login-reminder`) | M4 | planned |
| planned | Model generator: shared data models from the schema, with a CI freshness check (`feat/model-codegen`) | M5 | planned |
| planned | Python post-processor on the generated model; normalized JSON output (`feat/python-model`) | M5 | planned |
| planned | Lean Markdown view and command-line entry point (`feat/python-cli`) | M5 | planned |
| planned | Default post-processor: browser viewer (`feat/web-viewer`) | M6 | planned |
| planned | Single-file build and headless browser test (`feat/web-packaging`) | M6 | planned |
| planned | Remaining extractors, one pull request per topic (`feat/topic-<id>`) | M7 | planned |
| planned | Add-on packaging and manifest checks (`feat/packaging`) | M8 | planned |
| planned | release-please versioning and release PRs (`ci/release-please`) | M8 | planned |
| planned | Release artifacts and PyPI publishing (`ci/release-artifacts`) | M8 | planned |
| planned | User documentation (`docs/user-guide`) | M8 | planned |

**Housekeeping.** Tooling, docs and handoff changes that belong to no milestone and
gate none. They happen whenever they are needed, which is why they are numbered between
milestone work. CI is here, not in M0, because M0 was done before it was planned.

| PR | Title | State |
|---|---|---|
| [#5](https://github.com/choatej/ESOExporter/pull/5) | `CLAUDE.md` for agent sessions | merged |
| [#6](https://github.com/choatej/ESOExporter/pull/6) | Make the tracked kickoff notes the handoff | merged |
| [#8](https://github.com/choatej/ESOExporter/pull/8) | Next-step kickoff notes, a session prompt, and `CLAUDE.md` as the single entry point | merged |
| [#9](https://github.com/choatej/ESOExporter/pull/9) | Tie the roadmap to pull requests and order it by milestone | merged |
| [#10](https://github.com/choatej/ESOExporter/pull/10) | CI workflow and checks: `ci.yml`, Dependabot, repo hygiene script, CI badge | merged |
| [#11](https://github.com/choatej/ESOExporter/pull/11) | Move `main` protection to the ruleset only; update `CLAUDE.md` | merged |
| [#12](https://github.com/choatej/ESOExporter/pull/12) | Generate the shared data models from the schema (design docs) | merged |
| [#13](https://github.com/choatej/ESOExporter/pull/13) | `open-pr` skill and a check that the plan's pull request rows match GitHub | merged |
| [#16](https://github.com/choatej/ESOExporter/pull/16) | Development environment guide and `tools/dev-setup.sh` | open |

The CI and release plan is [CI_AND_RELEASES.md](CI_AND_RELEASES.md). The release rows in
M8 come from it.

### Kickoff notes for the next step

Replace this section when the next step's PR merges. Before writing anything, ask
the maintainer the questions below in one batch, each with a recommendation.

**Add-on skeleton** (`feat/addon-skeleton`, M2): the main add-on, the small data add-on
that owns `ESOExporterData`, the topic registry and the runner. The topic tree PR already
created `src/ESOExporter/` with a manifest (`ESOExporter.txt`) listing only
`TopicTreeData.lua` and `TopicTree.lua`, and defined the `ESOExporter` global namespace
(`ESOExporter.TopicTree`, `ESOExporter.TopicTreeData`); the skeleton builds on those and
does not redo them. Ask:

1. **Data add-on name.** `ESOExporterData` is provisional (it is also the name of the
   SavedVariables global). Recommendation: keep it.
2. **API version.** Check the current live value before writing it into the manifests (it
   was 101051 on 2026-11-14) and ask the maintainer to confirm it.
3. **Slash command names.** Recommendation: one root command, `/esoexport`, with
   subcommands (`save`, then `clear` and `status` later). Topic arguments are tree ids, and
   a group id expands through `TopicTree.TopicsUnder`.
4. **Registry shape.** Recommendation: a topic registers an extractor by its tree id
   (`Registry.Register("character.identity", fn)`); the runner takes the effective topic
   list from `TopicTree.Topics`, runs each extractor under `pcall`, and warns when a tree
   topic has no extractor. A registered id that is not a tree topic is an error.
5. **In-game check.** The skeleton adds code that touches the game, so the maintainer
   checks it in game (`/reloadui`, then look at the SavedVariables file). Plan that with
   them, and deploy with the `deploy-eso-addon` skill.

**What comes after the add-on skeleton.**

1. **Character identity extractor and `save` command** (`feat/identity-extractor`, M2):
   the first real output. It ends M2 when a real SavedVariables file validates against the
   schema; the real output then replaces the hand-built fixture after scrubbing. Its
   topic is `character.identity`.
2. **M3 extractors**, one pull request per topic id in the tree (`character.stats.*`,
   `character.equipment.*`, `character.skills.*`, `character.champion_points.*`). The
   tree's ids and groups are a starting catalog: an extractor PR may split, merge or
   rename nodes, and changes `tree.json`, the schema and the fixture together.

**Ready any time, outside the milestone order.** The M8 rows `feat/packaging`,
`ci/release-please` and `ci/release-artifacts` do not depend on the product work
([CI_AND_RELEASES.md](CI_AND_RELEASES.md)) and can be done earlier if the maintainer
wants; ask before starting one, because release-please needs the open decisions above
answered first.

#### Prompt for the next session

The standing instructions are in "Starting a session" in `CLAUDE.md`, so the prompt is:

```text
Read CLAUDE.md, ask the kickoff questions, then do the next step.
```

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| SavedVariables size or load time grows with exports | Report size, opt-in heavy topics, login reminder, clear command |
| Game updates change API results | Raw storage, `meta` records versions, per-extractor error isolation |
| Two post-processors drift apart | Shared schema, shared golden fixtures, identical-output test, and shared data models generated from the schema with a CI freshness check |
| Generated models do not capture schema semantics (enums, nil, `$parts`) | Annotate the schema instead of editing models; keep behavior in hand-written code |
| LibAddonMenu cannot express the topic tree | Fall back to a small custom panel; decide in M4 |
| Dependency libraries break or go stale | Optional dependencies with fallbacks; check update history before adopting |
| Personal data leaks through fixtures or reports | Scrubbed fixtures only; `.gitignore` rules; redaction option |
| Scope creep across topics | One topic per pull request, each with schema, fixture and tests |

## Open decisions

1. Name of the export library (currently `LibExportStore`; kept for now, see
   [#7](https://github.com/choatej/ESOExporter/pull/7)).
2. ~~Whether export data lives in a separate small add-on to get its own file.~~
   Decided in [#7](https://github.com/choatej/ESOExporter/pull/7): separate.
3. Technology and distribution of the default post-processor. This also picks the
   second model-generator target (item 6).
4. ~~Schema language details and validation.~~ Decided in [#7](https://github.com/choatej/ESOExporter/pull/7): JSON Schema draft
   2020-12, validated with Python `jsonschema` in `task test:python`.
5. Slash command names.
6. Model generator: tool per target, location (`tools/codegen/` or per project), and
   schema annotations needed. Decide before M5 starts, together with item 3.
6. Name of the data add-on that owns `ESOExporterData` (provisional), settled when it
   is created in the add-on skeleton pull request.
7. CI and release choices: generated changelog, one repository version, the token for
   release pull requests, ESOUI upload automation, a Pages copy of the web tool, release
   candidates. See "Open decisions" in [CI_AND_RELEASES.md](CI_AND_RELEASES.md); they are
   needed before the M8 release rows, not before.
8. Presets (M4). Maintainer direction from the topic tree PR: users get fine-grained control
   over what is exported, and presets are named starting points a user can pick and then
   diverge from easily, with no CharacterMarkdown-style config layer. The tree is already
   shaped for it (every node toggles; saved choices are a flat `id -> boolean` overrides table
   holding only differences from the defaults), so a preset can be an overrides table. Open:
   whether presets ship in the add-on or live in settings, how a diverged preset is shown,
   and which presets exist. Decide when M4 starts.

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
