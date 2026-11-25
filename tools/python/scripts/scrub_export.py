"""Scrub a real ESOExporterData SavedVariables file into a fixture that is safe to commit.

Usage: ``uv run python scripts/scrub_export.py <ESOExporterData.lua> <output.lua>``

Keeps `meta`, the account topics and the first character only. The character's id becomes
4500000000000001 and its name "Test Character One" (a name `schema/fixtures/allowed-names.txt`
permits). The input is read with the safe reader and never executed. Look at the output before
committing it: topics that hold names or other personal text need their own scrubbing rules, and
`task hygiene` catches only names it knows.
"""

import sys
from pathlib import Path
from typing import Any

from esoexporter import luadata

FAKE_ID = "4500000000000001"
FAKE_NAME = "Test Character One"


def scrub(export: dict[str, Any]) -> dict[str, Any]:
    result: dict[str, Any] = {"meta": export["meta"]}
    if "account" in export:
        result["account"] = export["account"]
    characters = export.get("characters") or {}
    if characters:
        first = characters[sorted(characters)[0]]
        result["characters"] = {FAKE_ID: {**first, "name": FAKE_NAME}}
    return result


def _key(key: object) -> str:
    return f'["{key}"]' if isinstance(key, str) else f"[{key}]"


def _lua(value: Any, depth: int) -> str:
    pad = "\t" * (depth + 1)
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int | float):
        return repr(value)
    if isinstance(value, str):
        return '"' + value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'
    items = value.items() if isinstance(value, dict) else enumerate(value, start=1)
    lines = [f"{pad}{_key(k)} = {_lua(v, depth + 1)}," for k, v in items]
    if not lines:
        return "{\n" + "\t" * depth + "}"
    return "{\n" + "\n".join(lines) + "\n" + "\t" * depth + "}"


def dump(export: dict[str, Any]) -> str:
    """Lua source in the way the game writes SavedVariables: one tab-indented global."""
    return "ESOExporterData =\n" + _lua(export, 0) + "\n"


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__)
        return 2
    export = luadata.load(Path(argv[1]))["ESOExporterData"]
    Path(argv[2]).write_text(dump(scrub(export)), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
