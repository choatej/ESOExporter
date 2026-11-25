#!/usr/bin/env bash
# Copy the add-ons in src/ into the game's AddOns folder.
#
# Usage: tools/deploy.sh [--dry-run]     (or: task deploy [-- --dry-run])
#
# Finds the game folder like tools/dev-setup.sh does; set ESO_LIVE_DIR if yours is elsewhere.
# Each add-on folder is replaced whole (so a deleted source file does not linger in the game),
# and nothing outside the add-ons listed below is touched. Then run /reloadui in game.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADDONS=(LibExportStore ESOExporterData ESOExporter)

dry=0
case "${1:-}" in
    "") ;;
    --dry-run) dry=1 ;;
    *)
        echo "usage: tools/deploy.sh [--dry-run]" >&2
        exit 2
        ;;
esac

candidates=()
[ -n "${ESO_LIVE_DIR:-}" ] && candidates+=("$ESO_LIVE_DIR")
if grep -qi microsoft /proc/version 2>/dev/null; then
    for dir in /mnt/c/Users/*/Documents/"Elder Scrolls Online"/live \
        /mnt/c/Users/*/OneDrive/Documents/"Elder Scrolls Online"/live; do
        candidates+=("$dir")
    done
elif [ "$(uname -s)" = Darwin ]; then
    candidates+=("$HOME/Documents/Elder Scrolls Online/live")
else
    suffix="steamapps/compatdata/306130/pfx/drive_c/users/steamuser/Documents/Elder Scrolls Online/live"
    candidates+=("$HOME/.steam/steam/$suffix" "$HOME/.local/share/Steam/$suffix"
        "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/$suffix")
fi

live=""
for dir in "${candidates[@]}"; do
    if [ -d "$dir/AddOns" ]; then
        live="$dir"
        break
    fi
done
if [ -z "$live" ]; then
    echo "deploy: game folder not found; set ESO_LIVE_DIR to the folder holding AddOns" >&2
    exit 1
fi

for name in "${ADDONS[@]}"; do
    if [ ! -f "$ROOT/src/$name/$name.txt" ]; then
        echo "deploy: src/$name/$name.txt is missing" >&2
        exit 1
    fi
done

echo "deploy: $ROOT/src -> $live/AddOns"
for name in "${ADDONS[@]}"; do
    if [ "$dry" = 1 ]; then
        echo "  would replace $name"
    else
        rm -rf "${live:?}/AddOns/${name:?}"
        cp -R "$ROOT/src/$name" "$live/AddOns/$name"
        echo "  replaced $name"
    fi
done
[ "$dry" = 1 ] || echo "deploy: done. Run /reloadui in game."
