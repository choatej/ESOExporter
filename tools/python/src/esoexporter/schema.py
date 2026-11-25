"""Load schema v1 with its topic schemas, ready to validate an export."""

import json
from pathlib import Path

from jsonschema import Draft202012Validator
from referencing import Registry, Resource
from referencing.jsonschema import DRAFT202012

ROOT = Path(__file__).resolve().parents[4]
SCHEMA_DIR = ROOT / "schema" / "v1"


def export_validator() -> Draft202012Validator:
    """A validator for the export envelope that also resolves each topic's own schema."""
    envelope = json.loads((SCHEMA_DIR / "export.schema.json").read_text(encoding="utf-8"))
    registry: Registry = Registry()
    for path in sorted((SCHEMA_DIR / "topics").glob("*.schema.json")):
        document = json.loads(path.read_text(encoding="utf-8"))
        registry = registry.with_resource(
            document["$id"], Resource.from_contents(document, DRAFT202012)
        )
    return Draft202012Validator(envelope, registry=registry)
