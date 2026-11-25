# Development environment

How to set up a machine to work on ESOExporter, on your own or with Claude Code.
`tools/dev-setup.sh` checks everything below and can install the user-local tools; this guide
explains what it checks and covers what it cannot do for you.

## Quick start

```sh
git clone https://github.com/choatej/ESOExporter.git ~/src/ESOExporter
cd ~/src/ESOExporter
tools/dev-setup.sh                 # check only; lists what is missing
sudo apt-get install -y luajit lua5.1 lua-check   # Debian, Ubuntu, WSL (see below for macOS)
tools/dev-setup.sh --install       # StyLua, Task and uv into ~/.local/bin; uv sync; commit email
task check                         # everything CI runs
lua5.1 tests/lua/run.lua           # the specs under stock Lua 5.1 too
```

`--install` never uses `sudo` and touches nothing outside `~/.local/bin` (or `--bin-dir`),
this checkout's git config and `tools/python/.venv`. It downloads pinned releases and checks
their SHA-256 checksums. Make sure `~/.local/bin` is on your `PATH`.

## Supported systems

| System | How |
|---|---|
| Linux | Directly. CI's `lua` and `repo-hygiene` jobs run on Ubuntu. |
| Windows | WSL 2 with Ubuntu. Work in the Linux file system (`~/src`), not under `/mnt/c`, for speed. The game's folder is reachable at `/mnt/c/Users/<you>/Documents/Elder Scrolls Online/live`. |
| macOS | Homebrew for LuaJIT and Luacheck; Lua 5.1 needs building (below). The script's macOS paths are untested *(verify)*. |

## Tools

| Tool | Used for | Version | Linux, WSL | macOS |
|---|---|---|---|---|
| git, curl, Python 3.11+ | everything; `task hygiene` is standard-library Python | any recent | system packages | Xcode tools, Homebrew |
| [Task](https://taskfile.dev) | `task check` and the other tasks in `Taskfile.yml` | 3.54.0 (`--install`) | `--install` | `--install` |
| LuaJIT | offline Lua specs (`task test`) | 2.1 | `apt install luajit` | `brew install luajit` |
| Lua 5.1 | the specs again under stock Lua, closer to the game | 5.1.5 | `apt install lua5.1` | build from [lua.org](https://www.lua.org/ftp/) (`make macosx`) *(verify)*; CI runs it either way |
| Luacheck | `task lint` | any | `apt install lua-check` | `brew install luarocks && luarocks install luacheck` |
| [StyLua](https://github.com/JohnnyMorganz/StyLua) | `task format`, `task format:check` | **0.20.0, the version CI pins**; other versions format differently | `--install` | `--install` |
| [uv](https://docs.astral.sh/uv/) | the Python project in `tools/python` (it fetches Python and the dev tools itself) | 0.13.7 (`--install`) | `--install` | `--install` |
| [gh](https://cli.github.com) | pull requests, `task hygiene:prs` | any | [packages](https://github.com/cli/cli/blob/trunk/docs/install_linux.md) | `brew install gh` |

The versions pinned in `tools/dev-setup.sh` are bumped by hand. StyLua must stay equal to the
version in `.github/workflows/ci.yml`.

## Git and GitHub

```sh
gh auth login
gh auth setup-git          # git pushes over HTTPS through gh
git config user.email 401076+choatej@users.noreply.github.com   # in this checkout; --install does it
```

`gh auth setup-git` is needed for Claude Code as well: a background session works in an
isolated git worktree and is not allowed to pass its own credential helper to `git push`, so
git must already know how to authenticate.

## The game

- **Game folder** (holds `AddOns/` and `SavedVariables/`):
  - Windows: `Documents\Elder Scrolls Online\live` (OneDrive may move `Documents`).
  - WSL: the same folder under `/mnt/c/Users/<you>/`.
  - macOS: `~/Documents/Elder Scrolls Online/live`.
  - Linux (Steam, Proton): inside the game's Proton prefix,
    `~/.steam/steam/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/Documents/Elder Scrolls Online/live`
    (also under `~/.local/share/Steam` or the Flatpak Steam folder) *(verify)*.

  `tools/dev-setup.sh` looks in these places; set `ESO_LIVE_DIR` if yours is elsewhere.
- **Deploying** the add-ons copies `src/LibExportStore`, `src/ESOExporterData` and
  `src/ESOExporter` into `AddOns/`, then `/reloadui` in game. `CLAUDE.md` asks Claude Code to
  use the `deploy-eso-addon` skill for this; it is a personal skill (below), not part of the repo.
- **API documentation.** ZOS publishes `ESOUIDocumentation.txt` with each API version; ESOUI
  posts it with the API patch notes *(verify where for the current version)*. Keep a copy at
  `docs/ESOUIDocumentation.txt`, which is git-ignored, and note its API version.

## Working with Claude Code

Install [Claude Code](https://claude.com/claude-code) and start sessions from the primary
checkout with the prompt in "Starting a session" in `CLAUDE.md`. Everything a session needs
from the repository is tracked (`CLAUDE.md`, the docs, the `open-pr` skill under
`.claude/skills/`). These are per machine and do **not** move with the repository, so copy or
recreate them on a new machine:

| Item | Where | Notes |
|---|---|---|
| Tools above | `PATH` | A session runs `tools/dev-setup.sh` and reports gaps; it should not install tools unasked. |
| `gh` login and credential helper | `~/.config/gh`, git config | See "Git and GitHub". |
| `deploy-eso-addon` skill | `~/.claude/skills/deploy-eso-addon/` | Personal skill; copy it from the old machine. |
| Claude Code memory for this project | `~/.claude/projects/<path-of-checkout>/memory/` | Keyed by the checkout's path, so keep the same path (`~/src/ESOExporter`) or copy it. |
| Private notes | `~/src/ESOExporter/.local/` | Git-ignored, primary checkout only. |
| Reference checkouts | `~/src/CharacterMarkdown`, `~/src/cm-dump-<date>/` | Read-only sources listed in `CLAUDE.md`. The dump holds real character data: copy it privately, never commit it. |
| ESO API documentation | `docs/ESOUIDocumentation.txt` | See "The game". |

Background sessions work in `.claude/worktrees/<name>/` (git-ignored) on their own branch and
can read, but not write, the primary checkout's `.local/`.

## Platforms and CI

CI runs the Lua job (LuaJIT, Lua 5.1, Luacheck, StyLua) and the hygiene job on Ubuntu, and the
Python job on Ubuntu (two Python versions), Windows and macOS. Linux players need no extra CI
job:

- **The add-on** runs inside the game's own Lua 5.1, which is the same on every platform. On
  Linux the game is the Windows client under Proton, so it behaves as on Windows, including
  where it writes SavedVariables (inside the Proton prefix) and the file it writes.
- **The Python post-processor** is already tested on Linux, and Linux is the strictest of the
  three for file names (case-sensitive), which the Ubuntu hygiene job also checks.
- **What differs on Linux** is only where the game folder is. When a post-processor learns to
  find SavedVariables on its own, give that lookup unit tests for every platform's paths (a
  fake home directory), which run on any CI runner.
