"""Validate scrubbed real exports in schema/fixtures/real/, and the scrub script itself."""

import copy
import sys
from pathlib import Path

import pytest

from esoexporter import luadata
from esoexporter.schema import ROOT, export_validator

sys.path.insert(0, str(ROOT / "tools" / "python" / "scripts"))
import scrub_export

REAL = sorted((ROOT / "schema" / "fixtures" / "real").glob("*.lua"))
HAND_BUILT = luadata.load(ROOT / "schema/fixtures/hand-built/ESOExporterData.lua")[
    "ESOExporterData"
]


@pytest.mark.parametrize("path", REAL, ids=[p.name for p in REAL])
def test_real_fixture_is_valid(path: Path) -> None:
    export = luadata.load(path)["ESOExporterData"]
    errors = [e.message for e in export_validator().iter_errors(export)]
    assert errors == []


def test_scrub_keeps_one_character_under_a_fake_id_and_name() -> None:
    real = copy.deepcopy(HAND_BUILT)
    real["characters"] = {"8800000000000009": {"name": "Somebody Real", "topics": {}}}
    scrubbed = scrub_export.scrub(real)
    assert scrubbed["characters"] == {
        scrub_export.FAKE_ID: {"name": scrub_export.FAKE_NAME, "topics": {}}
    }


def test_dump_round_trips_through_the_safe_reader() -> None:
    again = luadata.loads(scrub_export.dump(HAND_BUILT))["ESOExporterData"]
    assert again == HAND_BUILT
    assert not list(export_validator().iter_errors(again))
