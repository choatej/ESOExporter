# LibExportStore

Helpers for storing structured data in SavedVariables so an outside tool can read it.
Plain Lua 5.1, no dependencies, no SavedVariables of its own: the calling add-on owns the
container table and passes it in.

**Status:** version 0.1.0, in development inside the ESOExporter repository. The name is
provisional and the library is not published to ESOUI yet.

## Why

The game writes an add-on's SavedVariables to disk on `/reloadui`, logout or quit, and
that file is the only way data leaves the game. Two limits get in the way:

- A single string of **2000 characters or more is silently dropped** (confirmed by ZOS
  staff in 2020).
- Functions, userdata, NaN and cycles cannot be saved.

## Use

In your add-on manifest:

```
## DependsOn: LibExportStore
## SavedVariables: MyAddonData
```

```lua
local entry = LibExportStore.NewEntry(extractedTable, { timestamp = GetTimeStamp() })
MyAddonData = LibExportStore.Put(MyAddonData, { "characters", characterId, "topics", "equipment" }, entry)

-- entry.report says what was stored and what had to be dropped
-- LibExportStore.Summarize(MyAddonData) gives counts, ages and sizes for a reminder
```

## API

| Function | Purpose |
|---|---|
| `SplitText(text, maxLen)` | Cut text into pieces of at most `maxLen` bytes (default 1900), preferring line ends and never splitting a UTF-8 character. `maxLen` must be at least 4. |
| `JoinText(parts)` | Rejoin the pieces exactly. |
| `Sanitize(value, options)` | Copy a value into a storable form and return it with a report. Long strings become `{ ["$parts"] = { ... } }`. Never modifies the input. |
| `Restore(value)` | Rejoin sanitized long strings. |
| `NewEntry(value, options)` | Sanitize and wrap: `{ kind = "data", timestamp, data, report }`. |
| `Put(container, path, entry)` | Store an entry at `path` (an array of keys), creating tables as needed. Returns the container. |
| `Remove(container, path)` | Remove an entry. Returns whether anything was removed. |
| `Summarize(container)` | `{ entries, oldest, newest, nodes, stringBytes, dropped }` for the stored entries. |

`options` for `Sanitize` and `NewEntry`: `maxString` (default 1900), `maxDepth` (16),
`maxNodes` (200000), and for `NewEntry` also `timestamp`.

### What `Sanitize` drops

Each drop is counted in `report.dropped` and the first 50 are listed in `report.droppedList`
with their path:

- functions, userdata, threads, NaN and infinite numbers
- keys that are not strings or finite numbers, string keys longer than the limit, and the
  reserved key `"$parts"`
- cycles, and tables nested deeper than `maxDepth`

If the value has more than `maxNodes` nodes, the copy stops and `report.truncated` is true.

## Tests

`task test` from the repository root runs the offline specs in
`tests/lua/spec/export_store_spec.lua`, including a check that no stored string reaches
2000 characters.
