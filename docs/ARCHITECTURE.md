# Architecture

Status: **draft, agreed at project start.** Update this document in the same
pull request as any change that affects it. Anything marked *(verify)* is an
assumption about the game that must be checked in game before relying on it.
The delivery order is in [PROJECT_PLAN.md](PROJECT_PLAN.md).

## 1. Purpose and scope

ESOExporter extracts Elder Scrolls Online character and account data as nested
Lua tables and gets it out of the game through SavedVariables. Everything that
turns that data into a readable or shareable format happens outside the game.

The name is deliberately not "Character...": some data is account-level, and
anything the game exposes is in scope over time.

**Goals**

- A settings screen in game, so users choose a default set of topics once and
  never type a long command line (important on Steam Deck).
- The add-on, not the post-processor, decides what is extracted. Unselected
  topics cost nothing: no extraction time, no SavedVariables size.
- Formatting never runs in the game.
- A reusable export library that other add-ons can adopt.
- Two post-processors against one versioned contract.

**Non-goals**

- Writing files from the game (impossible) or any network access from the add-on.
- Console support. Consoles cannot reach SavedVariables files.
- Markdown or any display formatting inside the add-on.

## 2. Overview

```
 in game                                          outside the game
 ┌─────────────────────────────────────────┐     ┌───────────────────────┐
 │ Add-on                                  │     │ Post-processors       │
 │  settings screen -> topic selection     │     │  default (local web)  │
 │  extractors -> plain nested tables      │     │  Python CLI           │
 │  login reminder about stored data       │ SV  │  both read the schema │
 │            |                            │---->│  and share fixtures   │
 │            v                            │file └───────────────────────┘
 │ Export library (own manifest)           │
 │  sanitize, split, size report           │
 └─────────────────────────────────────────┘
```

Data flows one way: game, SavedVariables file, post-processor, output file.

## 3. Components

### 3.1 Add-on (`ESOExporter`)

| Module | Responsibility |
|---|---|
| Core | Namespace, version, chat output, game calls, event and command registration (`ESOExporter.lua`) |
| Topic registry | Maps each topic id of the tree to its extractor; rejects ids that are not tree topics (`Registry.lua`) |
| Extractors | One per topic. Read the game, return a plain table of raw values |
| Runner | Run extractors under `pcall`, sanitize, store at the schema path, report (`Runner.lua`; synchronous until LibAsync arrives in M3) |
| Settings | Saved defaults and the in-game settings panel |
| Commands | `/esoexport` (alias `/eox`); subcommands are added as needed, so far `save` (`Commands.lua` parses, selects topics and words replies) |
| Reminder | Login message about stored exports |

An extractor must not format. It returns what the game said: IDs, enums,
numbers, raw item links, and strings as given. See "Raw data" below.

An extractor file is listed in the manifest after `ESOExporter.lua` and calls
`ESOExporter.Register("<topic id>", function(id) ... return { ... } end)`. Registering an id
that is not a topic of the tree, a group, or a topic twice raises at load. The runner calls the
extractor with its topic id; an error or a result that is not a table fails that topic only, and
a tree topic with no extractor is counted in the summary. `/esoexport save` with no ids runs the
effective topics (the tree's defaults until settings exist); with ids, it runs every topic at or
below each one whatever its setting. Until settings exist, the main add-on declares no
SavedVariables of its own.

### 3.2 Export library (`LibExportStore`, name provisional)

A separate add-on folder with its own manifest (`## IsLibrary: true`,
`## AddOnVersion`; LibStub is deprecated for new libraries). It has **no
dependencies and declares no SavedVariables of its own.** A consuming add-on owns
its table and passes it in, so one consumer's data never loads for the others.

Responsibilities, all as pure functions over tables:

- `Sanitize`: copy a value into a form SavedVariables can store and report what
  was changed or dropped.
- `SplitText` / `JoinText`: cut text into parts under the string limit on UTF-8
  boundaries and rejoin it exactly.
- `Restore`: rejoin sanitized long strings.
- `NewEntry`, `Put`, `Remove`: build and maintain entries inside a container.
- `Summarize`: counts, ages and approximate size, for the login reminder.

It is published to ESOUI only after a second consumer exists or the API has
settled. Until then it lives in this repository.

### 3.3 Schema

The versioned contract between the add-on and every post-processor, kept in
`schema/`:

- The storage envelope (`schema/v1/export.schema.json`, JSON Schema draft 2020-12)
  and, as topics are added, the per-topic shapes. See `schema/README.md`.
- The topic tree (`schema/v1/tree.json`, shape in `tree.schema.json`): ids, labels,
  nesting, defaults, scope and cost class. It is the single source of truth for the settings
  screen and for the post-processors' topic selection. The game cannot read JSON, so the add-on
  loads a generated Lua copy (`src/ESOExporter/TopicTreeData.lua`); a test fails if the copy is
  out of date.
- Golden fixtures: scrubbed SavedVariables files plus the expected output of each
  post-processor.

### 3.4 Post-processors

Both read a SavedVariables file, validate it against the schema, rejoin
`$parts` strings, resolve names from reference data, and write output formats.

- **Default:** runs locally in a browser, nothing to install. Parses the Lua
  table text in the page; the file never leaves the machine.
- **Python:** a command-line tool for scripting. Already prototyped in the
  author's earlier work and ported here under test.

The two must produce the same normalized model from the same fixture. Output
formats (JSON, lean Markdown, build summaries) are added per tool.

#### Generated shared models

The shape of the data is defined once, in the schema, and the post-processors do not
hand-write it. The **shared data models** (the typed definitions of the envelope, the
topics and their fields) are **generated** from `schema/v1/` for each target language:
Python types for `tools/python`, and types for the default post-processor in whatever
language it ends up using. The generated files are committed, are marked as generated,
and are never edited by hand. CI regenerates them and fails if the result differs from
what is committed, so a schema change cannot reach one post-processor without the other.

Only the shared data models are generated. Everything else is specific to a
post-processor and is ordinary static code that each one owns: the Lua table parser, the
`$parts` rejoin, name resolution, normalization, output formats and the command-line or
browser interface. Those are behavior, not shape, and the golden fixtures plus the
identical-output test are what keep them in agreement.

The generator's input is the schema only. Where the schema cannot express something the
models need (for example which raw integer enum values map to which names), the fix is
an annotation in the schema, not a hand-edited model. The generators and the default
post-processor's language are chosen together; see the open questions.

## 4. Data model

### 4.1 Storage layout (schema v1)

The export lives in its own global, `ESOExporterData`, owned by a small separate data
add-on so it gets its own SavedVariables file (see section 7). The envelope is
specified in `schema/v1/export.schema.json`.

```lua
ESOExporterData = {
  meta = {
    schema = 1,
    addon = "ESOExporter", addonVersion = "0.1.0",
    apiVersion = 101051, gameVersion = "eso.live.12.1.7.3318083",
    server = "NA Megaserver",
  },
  account = {                        -- account-level topics
    topics = { ["account.currency"] = <entry>, ... },
  },
  characters = {
    ["<characterId>"] = {            -- stable id, not the name
      name = "...",
      topics = { ["character.equipment.worn"] = <entry>, ... },
    },
  },
}
```

A topic key is the topic's full dotted id from the topic tree (section 6).

An `<entry>` is `{ kind = "data", timestamp = <epoch>, data = <table>, report = <table> }`
(what `LibExportStore.NewEntry` builds). Characters are keyed by character id, a
decimal string, because names can change and repeat across servers *(verify)*.
Account-level and character-level topics are separate scopes so the layout does not
assume "character".

Rules the schema enforces: `meta` is required and `meta.schema` is 1; the top level
holds only `meta`, `account` and `characters`; no string reaches 2000 characters; the
key `$parts` appears only in a long-string table (`{ ["$parts"] = { ... } }`, joined
with no separator). Empty tables arrive as `{}` whether they were lists or objects,
because Lua cannot tell them apart; readers must allow for that. Adding optional
fields inside `meta` is not a breaking change. Adding a top-level key is.

### 4.2 Raw data

- Store IDs and enums as numbers, item links as the original string, and names
  only where the game returns a name and no ID exists.
- Resolve names, bonuses and links in post-processing. This keeps the add-on
  free of set-data library dependencies and keeps display decisions out of the game.
- Use `nil` for absent values, not placeholder strings.

### 4.3 Limits and the report

- A single string of 2000 characters or more is silently dropped by the game
  (confirmed by ZOS staff in 2020). `Sanitize` replaces a long string with
  `{ ["$parts"] = { ... } }`, each part at most 1900 bytes.
- Functions, userdata, threads, NaN, infinities, cycles, over-deep tables and
  keys that are not strings or numbers are dropped, and each is listed in the
  entry's `report`.
- Key counts are effectively unlimited since the 64-bit Lua VM. A modder reported
  about 130 MB as the practical ceiling before load times and crashes. The report
  includes an approximate byte count so size can be shown and capped.

## 5. Extraction pipeline

1. Read the effective topic selection from settings (or from a command argument).
2. Expand dependencies and order topics. Light topics run together; heavy topics
   (inventory, achievements) are opt-in.
3. Run each extractor under `pcall`. A failing extractor is recorded in the run
   report and never aborts the others.
4. Spread work across frames with LibAsync so the client never stalls *(M3; the runner
   is synchronous until then)*.
5. Sanitize each result into an entry and `Put` it into the container.
6. Print a one-line summary (counts, size, dropped values) and remind the user
   that the file is written on `/reloadui`, logout or quit.

## 6. Settings and the topic tree

- **Nodes.** The tree is made of *groups* (they only gate what is below them) and *topics*
  (leaves; each is one stored entry). Every node has a full dotted `id` in snake_case
  (`character.stats.offense`), a label, and a `default`. The two roots are the scopes,
  `account` and `character`. A topic also has a `scope` (equal to its root; it says where the
  entry is stored) and a `cost` (`light` or `heavy`). Heavy topics are off by default and run
  only when asked for. Ids are unique, and each id is its parent's id plus one segment.
- **A topic's id is its storage key.** The entry lives at
  `characters[<characterId>].topics["character.stats.offense"]` (or under `account.topics`).
  The export schema applies the same id pattern to topic keys, so a key that is not a
  well-formed path is rejected. Keys the tree does not know are allowed, so a file from a
  newer add-on still validates and post-processors skip what they do not know.
- **Fine-grained control.** Every node, group or topic, can be switched on or off by itself.
  A user is never forced to pick a bundle.
- **Structure and values are separate.** The tree is fixed and never saved. Saved choices
  are one flat table, `id -> boolean` (overrides), and only entries that differ from the
  node's default are stored (`TopicTree.Compact`). SavedVariables cannot hold functions or
  cycles, which a parent-linked tree would need. A saved id that a later version removed is
  ignored.
- **Gate semantics.** A node is effective when it and every ancestor are on. A child's
  stored value survives its parent being switched off, and counts again when the parent is
  switched back on. The effective state is derived top-down in one pass and kept in memory
  only (`TopicTree.Resolve`).
- **Code.** `src/ESOExporter/TopicTree.lua` is pure Lua with no game calls: `Index` (loads
  and validates the tree), `Resolve`, `Value`, `Topics` (effective topic ids, optionally of
  one scope), `TopicsUnder` (a group's topics, for command arguments) and `Compact`.
- **Presets are deferred to the settings milestone (M4).** The direction is named starting
  points that a user can pick and then diverge from node by node. Because choices are an
  overrides table, a preset can be one. There is no CharacterMarkdown-style config layer.
- **Panel.** The settings screen uses LibAddonMenu-2.0 *(verify that submenus
  can express the tree depth; otherwise a small custom panel)*.
- **Commands** accept the same ids for one-off exports; a group id means every topic
  below it.

## 7. SavedVariables handling

- `SavedVariables/<AddOn>.lua` contains every global the add-on lists
  *(verify)*. Settings and exports therefore share one file unless the export
  data is owned by a separate small add-on. Splitting keeps the data file easy
  to find, parse and delete. **Decided: separate.** A small data add-on
  `ESOExporterData` (`src/ESOExporterData/`, which lists the `ESOExporterData` global and has
  no code) owns the export file; the main add-on depends on it and on `LibExportStore`.
- SavedVariables are loaded into memory at login, so stored exports cost memory
  and load time until cleared. Exports are therefore meant to be short-lived.
- The file is written only on `/reloadui`, logout or quit, so a clear reaches
  the file on the next one of those.

## 8. Login reminder

On first player activation per session *(verify the event)*, if exports are
stored, print one line: how many, how old, approximate size, and how to clear
them. The add-on cannot know whether a post-processor ran, so it goes by age and
size. A setting disables the message and a setting can clear exports older than
a chosen age automatically.

## 9. Versioning and compatibility

- `meta.schema` is an integer. A breaking change increments it; post-processors
  support the current and previous schema and say so when they cannot read a file.
- The add-on follows Semantic Versioning once released. The manifest's
  `## APIVersion` is bumped for each game update after checking the changelog.
  The live API version was 101051 (game 12.1.7) when this was written.
- `meta` records add-on, API and game versions so a bug report is reproducible.

## 10. Dependencies

| Library | Plan |
|---|---|
| LibAsync | Required: spread extraction across frames |
| LibAddonMenu-2.0 | Required for the settings screen |
| LibCharacterKnowledge | Use at export time only, for crafting knowledge |
| LibItemSets | Optional, only if set data is needed in game |
| LibDebugLogger, LibChatMessage | Optional |

Policy: depend on a library only when it removes real work, check its license
and recent update history first, and prefer optional dependencies with a clear
fallback. No console-only libraries. The last survey of the ESOUI Libraries
category is summarized in the project plan.

## 11. Testing

- **Offline Lua tests** under LuaJIT (Lua 5.1) for all pure code: the export
  library, the topic tree, extractors against stubbed game functions.
- **Schema validation** in Python (`jsonschema`, under pytest), run by `task test:python`: the
  fixture must validate and deliberately broken copies must not. The Lua side checks
  the same fixture loads the way the game loads it and that its reports match the
  library's. Both post-processors validate against the same schema file.
- **Golden fixtures** shared by both post-processors.
- **Generated models are checked, not trusted:** a CI job regenerates them and fails on
  any difference from the committed files (see 3.4).
- **In-game checklist** for what cannot be stubbed: settings panel, login
  reminder, real extraction on a real character, SavedVariables round trip.

## 12. Security and privacy

- SavedVariables files from other people are untrusted input. Post-processors
  must parse them as data and never execute them.
- Exports can contain account and character names. Fixtures must be scrubbed,
  and post-processors should offer an option to redact identifiers.
- The add-on makes no network requests.

## 13. Repository layout

```
src/ESOExporter/       the add-on (folder name must match its manifest name)
src/ESOExporterData/   the data add-on: owns the ESOExporterData SavedVariables, no code
src/LibExportStore/    the export library (own manifest, IsLibrary)
schema/                v1/ envelope schema, tree.json and its schema, topic schemas; fixtures/
tools/python/          Python post-processor, a uv project (so far: a SavedVariables reader and schema tests)
tools/web/             default post-processor
tools/codegen/         generates the shared data models from the schema (planned, M5)
tools/dev-setup.sh     checks a development machine and installs user-local tools (docs/DEVELOPMENT.md)
tests/lua/             offline Lua tests
.github/               CI workflow (ci.yml), Dependabot, issue and PR templates
docs/                  this file and the project plan
```

## 14. Decisions

1. The add-on decides what is exported; settings are in game.
2. Formatting lives in post-processors only.
3. Two post-processors, one schema, shared fixtures.
4. The export library is separate, dependency-free and owns no SavedVariables.
   Export data lives in a separate small data add-on with its own SavedVariables file.
5. Data is stored raw; names and links are resolved outside the game.
6. Account-level and character-level scopes are first-class.
7. PC, macOS and Steam Deck only.
8. The shared data models are generated from the schema into each post-processor and
   checked in CI. Nothing else is generated; the rest of each post-processor is static
   code. (The generator tools are an open question.)

## 15. Open questions

- The default post-processor's technology and how it is distributed.
- The model generator: which tool per target (candidates are `datamodel-code-generator` for
  Python and `json-schema-to-typescript` for TypeScript), where it lives (`tools/codegen/`
  or in each project), and which schema annotations the models need. Depends on the
  default post-processor's technology.
- Whether LibAddonMenu can express the topic tree directly.
- The final name of the export library.
