"""The topic tree: its schema, the rules a schema cannot state, and its Lua copy."""

import copy
import json
from collections.abc import Callable, Iterator
from pathlib import Path
from typing import Any

import pytest
from jsonschema import Draft202012Validator

import gen_tree_lua
from esoexporter import luadata

ROOT = Path(__file__).resolve().parents[3]
TREE_SCHEMA = json.loads((ROOT / "schema/v1/tree.schema.json").read_text(encoding="utf-8"))
EXPORT_SCHEMA = json.loads((ROOT / "schema/v1/export.schema.json").read_text(encoding="utf-8"))
TREE = json.loads((ROOT / "schema/v1/tree.json").read_text(encoding="utf-8"))
FIXTURE = luadata.load(ROOT / "schema/fixtures/hand-built/ESOExporterData.lua")["ESOExporterData"]

VALIDATOR = Draft202012Validator(TREE_SCHEMA)

Change = Callable[[dict[str, Any]], object]


def walk(
    nodes: list[dict[str, Any]], parent: str | None = None
) -> Iterator[tuple[dict[str, Any], str | None]]:
    for node in nodes:
        yield node, parent
        yield from walk(node.get("children", []), node["id"])


def nodes_by_id() -> dict[str, dict[str, Any]]:
    return {node["id"]: node for node, _ in walk(TREE["nodes"])}


def find(tree: dict[str, Any], node_id: str) -> dict[str, Any]:
    return next(node for node, _ in walk(tree["nodes"]) if node["id"] == node_id)


REJECTIONS: dict[str, Change] = {
    "unknown version": lambda t: t.update(version=2),
    "no nodes": lambda t: t.update(nodes=[]),
    "unknown top-level key": lambda t: t.update(presets={}),
    "id in camelCase": lambda t: find(t, "account.currency").update(id="account.craftBag"),
    "id with an empty segment": lambda t: find(t, "account.currency").update(id="account..x"),
    "node of another type": lambda t: find(t, "account.currency").update(type="leaf"),
    "topic without scope": lambda t: find(t, "account.currency").pop("scope"),
    "topic with unknown scope": lambda t: find(t, "account.currency").update(scope="world"),
    "topic without cost": lambda t: find(t, "account.currency").pop("cost"),
    "topic with unknown cost": lambda t: find(t, "account.currency").update(cost="medium"),
    "topic without default": lambda t: find(t, "account.currency").pop("default"),
    "topic with children": lambda t: find(t, "account.currency").update(children=[]),
    "group without children": lambda t: find(t, "account.inventory").pop("children"),
    "group with no children": lambda t: find(t, "account.inventory").update(children=[]),
    "group with a scope": lambda t: find(t, "account.inventory").update(scope="account"),
    "default that is not a boolean": lambda t: find(t, "account.currency").update(default="yes"),
    "unknown node key": lambda t: find(t, "account.currency").update(preset="default"),
}


def test_schema_is_a_valid_schema() -> None:
    Draft202012Validator.check_schema(TREE_SCHEMA)


def test_tree_is_valid() -> None:
    assert sorted(e.message for e in VALIDATOR.iter_errors(TREE)) == []


@pytest.mark.parametrize("change", REJECTIONS.values(), ids=REJECTIONS.keys())
def test_broken_copies_are_rejected(change: Change) -> None:
    broken = copy.deepcopy(TREE)
    change(broken)
    assert list(VALIDATOR.iter_errors(broken)) != []


def test_ids_are_unique() -> None:
    ids = [node["id"] for node, _ in walk(TREE["nodes"])]
    assert len(ids) == len(set(ids))


def test_each_id_is_its_parents_id_plus_one_segment() -> None:
    for node, parent in walk(TREE["nodes"]):
        segment = node["id"].rsplit(".", 1)[-1]
        expected = segment if parent is None else f"{parent}.{segment}"
        assert node["id"] == expected


def test_roots_are_the_scopes() -> None:
    assert [node["id"] for node in TREE["nodes"]] == ["account", "character"]


def test_a_topics_scope_is_its_root() -> None:
    for node, _ in walk(TREE["nodes"]):
        if node["type"] == "topic":
            assert node["scope"] == node["id"].split(".")[0]


def test_heavy_topics_are_off_by_default() -> None:
    heavy = [n for n, _ in walk(TREE["nodes"]) if n["type"] == "topic" and n["cost"] == "heavy"]
    assert heavy
    assert all(n["default"] is False for n in heavy)


def test_export_schema_uses_the_same_id_pattern() -> None:
    export_pattern = EXPORT_SCHEMA["$defs"]["topics"]["propertyNames"]["pattern"]
    assert export_pattern == TREE_SCHEMA["$defs"]["id"]["pattern"]


def test_fixture_topics_are_in_the_tree_unless_synthetic() -> None:
    tree = nodes_by_id()
    stored = [("account", key) for key in FIXTURE["account"]["topics"]]
    for character in FIXTURE["characters"].values():
        stored += [("character", key) for key in character["topics"]]
    assert stored
    for scope, key in stored:
        if key.startswith("fixture."):
            continue
        assert tree[key]["type"] == "topic"
        assert tree[key]["scope"] == scope


def test_lua_copy_is_current() -> None:
    committed = (ROOT / gen_tree_lua.OUTPUT).read_text(encoding="utf-8")
    assert committed == gen_tree_lua.generate(ROOT)
