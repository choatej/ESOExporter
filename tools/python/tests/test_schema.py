"""Validate the fixture and some deliberately broken copies against schema v1."""

import copy
import json
from collections.abc import Callable
from pathlib import Path
from typing import Any

import pytest
from jsonschema import Draft202012Validator

from esoexporter import luadata

ROOT = Path(__file__).resolve().parents[3]
SCHEMA = json.loads((ROOT / "schema/v1/export.schema.json").read_text(encoding="utf-8"))
FIXTURE = luadata.load(ROOT / "schema/fixtures/hand-built/ESOExporterData.lua")["ESOExporterData"]
CHARACTER = "4500000000000002"

VALIDATOR = Draft202012Validator(SCHEMA)

Change = Callable[[dict[str, Any]], object]


def errors(document: dict[str, Any]) -> list[str]:
    return sorted(error.message for error in VALIDATOR.iter_errors(document))


def _long_text(d: dict[str, Any]) -> dict[str, Any]:
    return d["characters"][CHARACTER]["topics"]["fixture.long_text"]["data"]


def _currency(d: dict[str, Any]) -> dict[str, Any]:
    return d["account"]["topics"]["account.currency"]


REJECTIONS: dict[str, Change] = {
    "no meta": lambda d: d.pop("meta"),
    "other schema version": lambda d: d["meta"].update(schema=2),
    "missing api version": lambda d: d["meta"].pop("apiVersion"),
    "unknown top-level key": lambda d: d.update(settings={}),
    "character keyed by name": lambda d: d["characters"].update(
        {"Name": d["characters"][CHARACTER]}
    ),
    "character without name": lambda d: d["characters"][CHARACTER].pop("name"),
    "account without topics": lambda d: d["account"].pop("topics"),
    "bad topic id": lambda d: d["account"]["topics"].update({"Bad-Id": _currency(d)}),
    "camelCase topic id": lambda d: d["account"]["topics"].update({"craftBag": _currency(d)}),
    "topic id with an empty segment": lambda d: d["account"]["topics"].update(
        {"account..bank": _currency(d)}
    ),
    "topic id ending in a dot": lambda d: d["account"]["topics"].update({"account.": _currency(d)}),
    "entry of another kind": lambda d: _currency(d).update(kind="blob"),
    "entry without report": lambda d: _currency(d).pop("report"),
    "negative count": lambda d: _currency(d)["report"].update(nodes=-1),
    "string the game would drop": lambda d: _currency(d)["data"].update(x="a" * 2000),
    "dropped list item too long": lambda d: _currency(d)["report"].update(droppedList=["a" * 2000]),
    "empty $parts": lambda d: _long_text(d).update(text={"$parts": []}),
    "$parts with another key": lambda d: _long_text(d)["text"].update(extra=1),
    "$parts holding a number": lambda d: _long_text(d).update(text={"$parts": [1]}),
    "reserved key beside others": lambda d: _currency(d)["data"].update(
        {"$parts": ["a"], "other": 1}
    ),
}


def test_schema_is_a_valid_schema() -> None:
    Draft202012Validator.check_schema(SCHEMA)


def test_fixture_is_valid() -> None:
    assert errors(FIXTURE) == []


def test_minimal_export_is_valid() -> None:
    assert errors({"meta": FIXTURE["meta"]}) == []


def test_empty_lists_may_arrive_as_empty_tables() -> None:
    # An empty Lua table parses as {}; the fixture's reports already rely on it.
    entry = FIXTURE["characters"][CHARACTER]["topics"]["character.identity"]
    assert entry["report"]["droppedList"] == {}


@pytest.mark.parametrize("change", REJECTIONS.values(), ids=REJECTIONS.keys())
def test_broken_copies_are_rejected(change: Change) -> None:
    document = copy.deepcopy(FIXTURE)
    change(document)
    assert errors(document) != []
