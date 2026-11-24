# Schema

The versioned contract between the add-on and every post-processor.

| Path | What |
|---|---|
| `v1/export.schema.json` | The storage envelope of schema version 1 (JSON Schema draft 2020-12) |
| `v1/tree.json` | The topic tree: every group and topic a user can switch on or off |
| `v1/tree.schema.json` | The shape of `tree.json` |
| `fixtures/hand-built/ESOExporterData.lua` | A fixture written by hand to the schema; no real data |

Topic shapes are not part of the envelope. Each topic adds its own schema in the pull
request that adds the topic; until then an entry's `data` is any sanitized value.

## What the envelope fixes

- The export is the `ESOExporterData` global: `meta`, optional `account.topics`, and
  optional `characters[<characterId>]` with `name` and `topics`. See ARCHITECTURE.md 4.1.
- An entry is `{ kind = "data", timestamp, data, report }`, as `LibExportStore.NewEntry`
  builds it.
- No string reaches 2000 characters (the game drops those). Longer text is stored as
  `{ ["$parts"] = { ... } }`; join the parts with no separator.
- An empty Lua table is `{}` once parsed, whether it was a list or an object. Readers
  accept both.

## The topic tree

`tree.json` lists groups and topics. Each node has a full dotted snake_case `id`
(`character.stats.offense`), a label and a `default`; a topic also has a `scope` (`account` or
`character`) and a `cost` (`light` or `heavy`). A topic's id is its key under `topics` in an
export, and the envelope schema applies the same id pattern to those keys. See ARCHITECTURE.md 6.

The schema cannot state that ids are unique, that each id is its parent's id plus one segment,
or that a topic's scope is its root; the Python tests and the Lua loader check those.

The game cannot read JSON, so `src/ESOExporter/TopicTreeData.lua` is generated from `tree.json`:

```sh
python3 tools/python/scripts/gen_tree_lua.py          # rewrite it after editing tree.json
python3 tools/python/scripts/gen_tree_lua.py --check  # fail if it is out of date
```

A test (`test_lua_copy_is_current`) fails when the two disagree.

## Versioning

`meta.schema` is an integer. A breaking change adds `v2/` next to `v1/`; post-processors
support the current and previous version. Optional additions inside `meta` do not bump it.

## Checking

```sh
task test:python        # needs uv; or `uv run pytest` in tools/python
```

The Python tests parse the fixture with a safe reader (`tools/python/esoexporter/luadata.py`,
which never executes the file), validate it, and confirm that deliberately broken copies fail.
`task test` checks the same fixture from the Lua side.

## Fixtures

Fixtures are scrubbed or invented. Real SavedVariables files and personal data never enter
the repository. The hand-built fixture is replaced by scrubbed real output once the add-on
produces some.
