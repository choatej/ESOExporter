"""Validate the fixture and some deliberately broken copies against schema v1."""

import copy
import json
import unittest
from pathlib import Path

from jsonschema import Draft202012Validator

from esoexporter import luadata

ROOT = Path(__file__).resolve().parents[3]
SCHEMA = json.loads((ROOT / "schema/v1/export.schema.json").read_text(encoding="utf-8"))
FIXTURE = luadata.load(ROOT / "schema/fixtures/hand-built/ESOExporterData.lua")["ESOExporterData"]
CHARACTER = "4500000000000002"

VALIDATOR = Draft202012Validator(SCHEMA)


def errors(document):
    return sorted(error.message for error in VALIDATOR.iter_errors(document))


def broken(change):
    document = copy.deepcopy(FIXTURE)
    change(document)
    return document


class SchemaTests(unittest.TestCase):
    def test_schema_is_a_valid_schema(self):
        Draft202012Validator.check_schema(SCHEMA)

    def test_fixture_is_valid(self):
        self.assertEqual(errors(FIXTURE), [])

    def test_minimal_export_is_valid(self):
        meta = FIXTURE["meta"]
        self.assertEqual(errors({"meta": meta}), [])

    def test_empty_lists_may_arrive_as_empty_tables(self):
        # An empty Lua table parses as {}; the fixture's reports already rely on it.
        entry = FIXTURE["characters"][CHARACTER]["topics"]["identity"]
        self.assertEqual(entry["report"]["droppedList"], {})

    def test_rejections(self):
        cases = {
            "no meta": lambda d: d.pop("meta"),
            "other schema version": lambda d: d["meta"].update(schema=2),
            "missing api version": lambda d: d["meta"].pop("apiVersion"),
            "unknown top-level key": lambda d: d.update(settings={}),
            "character keyed by name": lambda d: d["characters"].update({"Name": d["characters"][CHARACTER]}),
            "character without name": lambda d: d["characters"][CHARACTER].pop("name"),
            "account without topics": lambda d: d["account"].pop("topics"),
            "bad topic id": lambda d: d["account"]["topics"].update({"Bad_Id": d["account"]["topics"]["currency"]}),
            "entry of another kind": lambda d: d["account"]["topics"]["currency"].update(kind="blob"),
            "entry without report": lambda d: d["account"]["topics"]["currency"].pop("report"),
            "negative count": lambda d: d["account"]["topics"]["currency"]["report"].update(nodes=-1),
            "string the game would drop": lambda d: d["account"]["topics"]["currency"]["data"].update(x="a" * 2000),
            "dropped list item too long": lambda d: d["account"]["topics"]["currency"]["report"].update(
                droppedList=["a" * 2000]
            ),
            "empty $parts": lambda d: d["characters"][CHARACTER]["topics"]["fixtureLongText"]["data"].update(
                text={"$parts": []}
            ),
            "$parts with another key": lambda d: d["characters"][CHARACTER]["topics"]["fixtureLongText"]["data"][
                "text"
            ].update(extra=1),
            "$parts holding a number": lambda d: d["characters"][CHARACTER]["topics"]["fixtureLongText"]["data"].update(
                text={"$parts": [1]}
            ),
            "reserved key beside others": lambda d: d["account"]["topics"]["currency"]["data"].update(
                {"$parts": ["a"], "other": 1}
            ),
        }
        for name, change in cases.items():
            with self.subTest(name):
                self.assertNotEqual(errors(broken(change)), [])


if __name__ == "__main__":
    unittest.main()
