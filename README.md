# ESOExporter

[![License: MIT](https://img.shields.io/github/license/choatej/ESOExporter)](LICENSE)
![Status: pre-alpha](https://img.shields.io/badge/status-pre--alpha-orange)
![Lua 5.1](https://img.shields.io/badge/Lua-5.1-2C2D72?logo=lua&logoColor=white)

An Elder Scrolls Online add-on that extracts character and account data into
structured Lua tables, plus tools that turn that data into whatever format you
need (Markdown, JSON, and more).

> **Status: pre-alpha.** Nothing is released yet. This repository currently holds
> the project scaffold and design notes. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Why

ESO add-ons cannot write files. The one way data leaves the game is the
SavedVariables file, which the client writes on `/reloadui`, logout or quit.
ESOExporter treats that as the contract:

1. **The add-on** extracts the data you chose (in-game settings screen, no
   command line needed) as plain nested Lua tables.
2. **A small export library** stores them safely in SavedVariables (the game
   silently drops any single string of 2000 characters or more, so long text is
   split, and unsupported values are reported instead of lost).
3. **Post-processors** read the SavedVariables file outside the game and do the
   formatting. Formatting never runs inside the game.

## Planned components

| Component | Purpose |
|---|---|
| Add-on | Settings screen, topic selection, extraction, login reminders about stored data |
| Export library | Chunking, sanitizing and versioned storage in SavedVariables; reusable by other add-ons |
| Schema | The versioned data contract shared by every post-processor |
| Post-processor (default) | Reads SavedVariables locally, with nothing to install beyond a browser |
| Post-processor (Python) | Command-line tool for scripting and automation |

## Install

Not available yet.

## Contributing

Contributions are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md) for the
workflow (branches and squash-merged pull requests).

## Acknowledgments

ESOExporter is inspired by [CharacterMarkdown](https://github.com/solaegis/CharacterMarkdown)
by solaegis and its contributors, the add-on that showed how useful a character
export can be. ESOExporter is an independent project with its own architecture
and shares no code with it.

## Disclaimer

This add-on is not created by, affiliated with or sponsored by ZeniMax Media Inc.
or its affiliates. The Elder Scrolls® and related logos are registered
trademarks or trademarks of ZeniMax Media Inc. in the United States and/or other
countries. All rights reserved.

## License

[MIT](LICENSE)
