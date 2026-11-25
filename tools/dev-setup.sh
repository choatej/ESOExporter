#!/usr/bin/env bash
# Check (and optionally set up) a development environment for ESOExporter.
# See docs/DEVELOPMENT.md for the full guide.
#
#   tools/dev-setup.sh                 check only; exits 1 if a required tool is missing
#   tools/dev-setup.sh --install       also install the user-local tools (no sudo) and sync Python
#   tools/dev-setup.sh --install --bin-dir DIR    install into DIR instead of ~/.local/bin
#
# --install downloads pinned releases of StyLua, Task and uv into the bin directory and verifies
# their SHA-256 checksums, sets this checkout's commit email to the GitHub noreply address, and
# runs `uv sync` in tools/python. It never uses sudo: system packages (LuaJIT, Lua 5.1, Luacheck)
# are printed as a command for you to run. Linux (including WSL) and macOS are supported.

set -euo pipefail

# Pinned versions. StyLua must match the version CI uses (.github/workflows/ci.yml), because
# formatting differs between StyLua releases.
STYLUA_VERSION="0.20.0"
TASK_VERSION="3.54.0"
UV_VERSION="0.13.7"
NOREPLY_EMAIL="401076+choatej@users.noreply.github.com"

# StyLua publishes no checksums; these were computed from the v0.20.0 release assets.
stylua_sha256() {
    case "$1" in
        linux-x86_64) echo "28eddb9257bf85b20b1c337e536b7a3d16ba308863f067d447c1f4d24c6dec64" ;;
        linux-aarch64) echo "376b675766bc0b9261b2b82c8d0f624c7e5f78e83bd8490330e0bf3d8f770ad7" ;;
        macos-x86_64) echo "858a3f6b69aaf4a1f94809f0371edb4b27fa8d1db230b55780c4b51194bc7125" ;;
        macos-aarch64) echo "f1b1cf758fd4346248c78640c9b62610b811b87190942ea828a8228dd8292ee6" ;;
        *) return 1 ;;
    esac
}

INSTALL=0
BIN_DIR="${HOME}/.local/bin"
while [ $# -gt 0 ]; do
    case "$1" in
        --install) INSTALL=1 ;;
        --bin-dir)
            BIN_DIR="${2:?--bin-dir needs a directory}"
            shift
            ;;
        -h | --help)
            sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "unknown option: $1 (try --help)" >&2
            exit 2
            ;;
    esac
    shift
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="${BIN_DIR}:${PATH}"

# ---------------------------------------------------------------- platform

OS="$(uname -s)"
ARCH="$(uname -m)"
WSL=0
if [ "$OS" = "Linux" ] && grep -qi microsoft /proc/version 2>/dev/null; then
    WSL=1
fi
case "$ARCH" in
    x86_64 | amd64) ARCH=x86_64 ;;
    aarch64 | arm64) ARCH=aarch64 ;;
    *)
        echo "unsupported CPU architecture: $ARCH" >&2
        exit 2
        ;;
esac
case "$OS" in
    Linux) ;;
    Darwin) ;;
    *)
        echo "unsupported system: $OS (on Windows, use WSL 2; see docs/DEVELOPMENT.md)" >&2
        exit 2
        ;;
esac

# ---------------------------------------------------------------- output

MISSING=0
LOCAL_MISSING=0 # StyLua, Task or uv, which --install provides
ok() { printf '  ok      %s\n' "$*"; }
missing() {
    printf '  MISSING %s\n' "$*"
    MISSING=$((MISSING + 1))
}
note() { printf '  note    %s\n' "$*"; }
section() { printf '\n%s\n' "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }

sha256_of() {
    if have sha256sum; then
        sha256sum "$1" | cut -d' ' -f1
    else
        shasum -a 256 "$1" | cut -d' ' -f1
    fi
}

# ---------------------------------------------------------------- installers

WORK=""
cleanup() { [ -n "$WORK" ] && rm -rf "$WORK"; }
trap cleanup EXIT

download() { # url, destination, expected sha256
    curl -sSfL -o "$2" "$1"
    local actual
    actual="$(sha256_of "$2")"
    if [ "$actual" != "$3" ]; then
        echo "checksum mismatch for $1: expected $3, got $actual" >&2
        exit 1
    fi
}

install_stylua() {
    local platform
    platform="$([ "$OS" = Darwin ] && echo macos || echo linux)-${ARCH}"
    local url="https://github.com/JohnnyMorganz/StyLua/releases/download/v${STYLUA_VERSION}/stylua-${platform}.zip"
    download "$url" "$WORK/stylua.zip" "$(stylua_sha256 "$platform")"
    python3 -I -m zipfile -e "$WORK/stylua.zip" "$WORK/stylua"
    install -m 0755 "$WORK/stylua/stylua" "$BIN_DIR/stylua"
}

install_task() {
    local platform
    platform="$([ "$OS" = Darwin ] && echo darwin || echo linux)_$([ "$ARCH" = x86_64 ] && echo amd64 || echo arm64)"
    local base="https://github.com/go-task/task/releases/download/v${TASK_VERSION}"
    curl -sSfL -o "$WORK/task_checksums.txt" "$base/task_checksums.txt"
    local sum
    sum="$(grep " task_${platform}.tar.gz\$" "$WORK/task_checksums.txt" | cut -d' ' -f1)"
    download "$base/task_${platform}.tar.gz" "$WORK/task.tar.gz" "$sum"
    mkdir -p "$WORK/task"
    tar -xzf "$WORK/task.tar.gz" -C "$WORK/task"
    install -m 0755 "$WORK/task/task" "$BIN_DIR/task"
}

install_uv() {
    local target
    target="${ARCH}-$([ "$OS" = Darwin ] && echo apple-darwin || echo unknown-linux-gnu)"
    local base="https://github.com/astral-sh/uv/releases/download/${UV_VERSION}"
    local sum
    sum="$(curl -sSfL "$base/uv-${target}.tar.gz.sha256" | cut -d' ' -f1)"
    download "$base/uv-${target}.tar.gz" "$WORK/uv.tar.gz" "$sum"
    tar -xzf "$WORK/uv.tar.gz" -C "$WORK"
    install -m 0755 "$WORK/uv-${target}/uv" "$BIN_DIR/uv"
    install -m 0755 "$WORK/uv-${target}/uvx" "$BIN_DIR/uvx"
}

if [ "$INSTALL" = 1 ]; then
    if ! have curl || ! have python3; then
        echo "--install needs curl and python3" >&2
        exit 1
    fi
    WORK="$(mktemp -d)"
    mkdir -p "$BIN_DIR"
    echo "Installing user-local tools into $BIN_DIR"
    if [ "$(stylua --version 2>/dev/null)" != "stylua ${STYLUA_VERSION}" ]; then
        install_stylua && echo "  installed stylua ${STYLUA_VERSION}"
    fi
    if ! have task; then
        install_task && echo "  installed task ${TASK_VERSION}"
    fi
    if ! have uv; then
        install_uv && echo "  installed uv ${UV_VERSION}"
    fi
    if [ "$(git -C "$ROOT" config user.email || true)" != "$NOREPLY_EMAIL" ]; then
        git -C "$ROOT" config user.email "$NOREPLY_EMAIL"
        echo "  set this checkout's commit email to $NOREPLY_EMAIL"
    fi
    if have uv; then
        (cd "$ROOT/tools/python" && uv sync --locked --quiet) && echo "  synced the Python project (tools/python)"
    fi
fi

# ---------------------------------------------------------------- checks

platform_label="$OS $ARCH"
[ "$WSL" = 1 ] && platform_label="$platform_label (WSL)"
echo "ESOExporter development environment: $platform_label"

section "Required for the checks (task check)"
for tool in git python3 task luajit lua5.1 luacheck stylua uv; do
    if have "$tool"; then
        case "$tool" in
            stylua)
                version="$(stylua --version 2>/dev/null)"
                if [ "$version" = "stylua ${STYLUA_VERSION}" ]; then
                    ok "$version"
                else
                    missing "stylua ${STYLUA_VERSION} (found '$version'; CI uses ${STYLUA_VERSION})"
                    LOCAL_MISSING=1
                fi
                ;;
            python3)
                if python3 -c 'import sys; sys.exit(sys.version_info < (3, 11))'; then
                    ok "$(python3 --version)"
                else
                    missing "python3 3.11 or later (found $(python3 --version 2>&1))"
                fi
                ;;
            luajit) ok "$(luajit -v 2>&1 | head -1)" ;;
            lua5.1) ok "$(lua5.1 -v 2>&1 | head -1)" ;;
            *) ok "$tool ($(command -v "$tool"))" ;;
        esac
    else
        missing "$tool"
        case "$tool" in stylua | task | uv) LOCAL_MISSING=1 ;; esac
    fi
done

section "Pull requests and Claude Code"
if have gh; then
    if gh auth status >/dev/null 2>&1; then
        ok "gh is logged in"
    else
        missing "gh login: run 'gh auth login'"
    fi
    if git config --get-all credential.https://github.com.helper 2>/dev/null | grep -q "gh auth git-credential"; then
        ok "git pushes over HTTPS through gh"
    else
        missing "gh as git's credential helper: run 'gh auth setup-git' (worktree sessions cannot push otherwise)"
    fi
else
    missing "gh (GitHub CLI)"
fi
email="$(git -C "$ROOT" config user.email || true)"
if [ "$email" = "$NOREPLY_EMAIL" ]; then
    ok "commit email is the noreply address"
else
    missing "commit email: run 'git config user.email $NOREPLY_EMAIL' (found '${email:-none}')"
fi
if have claude; then
    ok "claude ($(claude --version 2>/dev/null | head -1))"
else
    note "claude (Claude Code) not on PATH; only needed for agent sessions"
fi

section "Game and reference material (optional; see docs/DEVELOPMENT.md)"
live=""
candidates=()
if [ -n "${ESO_LIVE_DIR:-}" ]; then
    candidates+=("$ESO_LIVE_DIR")
fi
if [ "$WSL" = 1 ]; then
    for dir in /mnt/c/Users/*/Documents/"Elder Scrolls Online"/live \
        /mnt/c/Users/*/OneDrive/Documents/"Elder Scrolls Online"/live; do
        candidates+=("$dir")
    done
elif [ "$OS" = Darwin ]; then
    candidates+=("$HOME/Documents/Elder Scrolls Online/live")
else
    # Steam (Proton) prefixes; 306130 is the game's Steam app id.
    suffix="steamapps/compatdata/306130/pfx/drive_c/users/steamuser/Documents/Elder Scrolls Online/live"
    candidates+=("$HOME/.steam/steam/$suffix" "$HOME/.local/share/Steam/$suffix"
        "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/$suffix")
fi
for dir in "${candidates[@]}"; do
    if [ -d "$dir/AddOns" ]; then
        live="$dir"
        break
    fi
done
if [ -n "$live" ]; then
    ok "game folder: $live"
else
    note "game folder not found; set ESO_LIVE_DIR to the folder holding AddOns and SavedVariables"
fi
if [ -d "$HOME/.claude/skills/deploy-eso-addon" ] || [ -d "$ROOT/.claude/skills/deploy-eso-addon" ]; then
    ok "deploy-eso-addon skill"
else
    note "deploy-eso-addon skill not installed (a personal Claude Code skill; see docs/DEVELOPMENT.md)"
fi
docs_found=0
for doc in "$ROOT/docs/ESOUIDocumentation.txt" "$HOME/src/CharacterMarkdown/ESOUIDocumentationP50.txt"; do
    if [ -f "$doc" ]; then
        ok "API documentation: $doc"
        docs_found=1
    fi
done
[ "$docs_found" = 1 ] || note "no ESO API documentation file found (see docs/DEVELOPMENT.md)"
if [ -d "$HOME/src/CharacterMarkdown/.git" ]; then
    ok "CharacterMarkdown checkout: ~/src/CharacterMarkdown"
else
    note "no ~/src/CharacterMarkdown checkout (read-only reference)"
fi

# ---------------------------------------------------------------- summary

echo
if [ "$MISSING" -gt 0 ]; then
    echo "$MISSING required item(s) missing."
    if [ "$OS" = Linux ]; then
        echo "System packages (Debian, Ubuntu, WSL): sudo apt-get install -y luajit lua5.1 lua-check"
    else
        echo "System packages (macOS, Homebrew): brew install luajit luarocks && luarocks install luacheck"
        echo "  Homebrew has no Lua 5.1; see docs/DEVELOPMENT.md."
    fi
    [ "$LOCAL_MISSING" = 0 ] || echo "User-local tools (StyLua, Task, uv): tools/dev-setup.sh --install"
    exit 1
fi
echo "Everything required is in place. Run 'task check' to confirm."
