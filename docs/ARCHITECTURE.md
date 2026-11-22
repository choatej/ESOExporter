# Architecture (draft)

This is the design as agreed at project start. It will change; update it in the
same pull request as the change.

## Goal

Extract ESO character and account data as nested Lua tables and get it out of
the game through SavedVariables. Formatting happens outside the game. The name
is deliberately not "Character...": some data is account-level, and anything
exportable is in scope over time.

## Components

```
 in game                                          outside the game
 ┌─────────────────────────────────────────┐     ┌───────────────────────┐
 │ Add-on                                  │     │ Post-processors       │
 │  settings screen -> topic selection     │     │  default (local web)  │
 │  extractors -> plain nested tables      │     │  Python CLI           │
 │  login reminder about stored data       │ SV  │  both read the schema │
 │            |                            │---->│                       │
 │            v                            │file └───────────────────────┘
 │ Export library (own manifest)           │
 │  sanitize, chunk, version, size report  │
 └─────────────────────────────────────────┘
```

## Decisions

1. **The add-on decides what is exported.** The user picks topics in an in-game
   settings screen and saves defaults, so no long command line is needed
   (important on Steam Deck). Only selected topics are extracted, which keeps
   extraction time and SavedVariables size down. Heavy topics (inventory,
   achievements) are opt-in.
2. **Formatting lives in post-processors, not the add-on.** The add-on emits
   data, never Markdown.
3. **Two post-processors, one contract.** A default one that needs nothing
   installed, and a Python CLI. Both are built against a versioned schema and
   tested against shared golden fixtures so they cannot drift apart.
4. **The export library is separate.** It has its own manifest
   (`## IsLibrary: true`, `## AddOnVersion`; LibStub is deprecated for new
   libraries) and **declares no SavedVariables of its own**. A consuming add-on
   owns its table and passes it in, so one consumer's data never loads for the
   others. Publish it to ESOUI once it has a second consumer or a stable API.
5. **Stored data is raw.** Item links and enums are stored as the game gives
   them, with IDs rather than display names. Names, set bonuses and links are
   resolved in post-processing. This avoids runtime dependencies on set-data
   libraries.
6. **Login reminder.** When exports are stored, the add-on can say how many,
   how old and how large they are, and offer to clear them. It cannot know
   whether a post-processor ran, so it goes by age and size. A clear reaches the
   file on the next `/reloadui` or logout.
7. **Platform:** PC, macOS and Steam Deck. Consoles cannot reach SavedVariables
   files, so console libraries are out of scope.

## SavedVariables constraints

- A single string of 2000 characters or more is silently dropped by the game
  (confirmed by ZOS staff in 2020). Long text is stored as parts of at most
  1900 bytes, split on UTF-8 character boundaries.
- Functions, NaN and cycles cannot be saved. The export library drops them and
  records a report.
- SavedVariables load into memory at login. Large exports cost memory and load
  time until cleared, so size is reported and exports are cleared after use.

## Library candidates

| Library | Plan |
|---|---|
| LibAsync | Use: spread extraction across frames |
| LibCharacterKnowledge | Use at export time only, for crafting knowledge |
| LibAddonMenu-2.0 | Use for the settings screen |
| LibItemSets | Optional, only if set data is needed in game |
| LibDebugLogger, LibChatMessage | Optional |

Verify each library's current version and license before depending on it.

## Open questions

- The default post-processor: browser-based, reading the file locally, is the
  working assumption.
- Schema format and where the golden fixtures live.
- Whether the settings screen can express the topic tree with LibAddonMenu
  submenus, or needs a custom panel.
