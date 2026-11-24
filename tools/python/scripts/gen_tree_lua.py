"""Generate the Lua copy of the topic tree that the add-on loads.

The game cannot read JSON, so `schema/v1/tree.json` (the source of truth, which the
post-processors read) is also shipped as a Lua table, `src/ESOExporter/TopicTreeData.lua`. The
Lua file is generated and never edited by hand; a test fails if it differs from what this script
would write.

Usage: ``python3 tools/python/scripts/gen_tree_lua.py [--check] [repository root]``
Without ``--check`` it rewrites the file. With it, it only reports whether the file is current.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

TREE = "schema/v1/tree.json"
OUTPUT = "src/ESOExporter/TopicTreeData.lua"

# Order of the keys in each node, so the output does not depend on how tree.json is written.
KEYS = ("id", "type", "label", "description", "default", "scope", "cost", "children")

HEADER = """\
-- GENERATED from schema/v1/tree.json by tools/python/scripts/gen_tree_lua.py. Do not edit.
-- Edit tree.json, then run `python3 tools/python/scripts/gen_tree_lua.py`. A test fails when
-- this file is out of date.

ESOExporter = ESOExporter or {}
"""


def lua_string(text: str) -> str:
    if not text.isascii() or not text.isprintable():
        raise ValueError(f"only printable ASCII is supported in tree text, got {text!r}")
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def lua_value(value: Any) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, str):
        return lua_string(value)
    raise TypeError(f"unsupported value {value!r}")


def lua_node(node: dict[str, Any], depth: int) -> str:
    pad = "    " * (depth + 1)
    lines = ["{"]
    unknown = set(node) - set(KEYS)
    if unknown:
        raise ValueError(f"unknown node keys {sorted(unknown)} in {node.get('id')!r}")
    for key in KEYS:
        if key not in node:
            continue
        if key == "children":
            children = ",\n".join(pad + "    " + lua_node(c, depth + 2) for c in node["children"])
            lines.append(f"{pad}children = {{\n{children},\n{pad}}},")
        else:
            lines.append(f"{pad}{key} = {lua_value(node[key])},")
    lines.append("    " * depth + "}")
    return "\n".join(lines)


def render(tree: dict[str, Any]) -> str:
    nodes = ",\n".join("        " + lua_node(n, 2) for n in tree["nodes"])
    return (
        HEADER
        + "ESOExporter.TopicTreeData = {\n"
        + f"    version = {tree['version']},\n"
        + f"    nodes = {{\n{nodes},\n    }},\n"
        + "}\n\n"
        + "return ESOExporter.TopicTreeData\n"
    )


def generate(root: Path) -> str:
    tree = json.loads((root / TREE).read_text(encoding="utf-8"))
    return render(tree)


def main(argv: list[str]) -> int:
    check = "--check" in argv
    rest = [a for a in argv if a != "--check"]
    root = Path(rest[0]) if rest else Path(__file__).resolve().parents[3]
    expected = generate(root)
    target = root / OUTPUT
    if check:
        if not target.is_file() or target.read_text(encoding="utf-8") != expected:
            print(f"{OUTPUT} is out of date; run tools/python/scripts/gen_tree_lua.py")
            return 1
        return 0
    target.write_text(expected, encoding="utf-8")
    print(f"wrote {OUTPUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
