from pathlib import Path

import pytest

import check_hygiene as hygiene

ROOT = Path(__file__).resolve().parents[3]


def write(root: Path, relative: str, text: str) -> None:
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def test_repository_passes() -> None:
    assert hygiene.run_checks(ROOT) == []


@pytest.mark.parametrize(
    "path", ["SavedVariables/ESOExporterData.lua", "exports/a.json", "docs/x_export_1.json"]
)
def test_blocked_paths_are_reported(path: str) -> None:
    assert hygiene.check_blocked_paths([path], []) != []


def test_ordinary_paths_and_ignored_tracked_files() -> None:
    assert hygiene.check_blocked_paths(["src/a.lua", "schema/fixtures/x.lua"], []) == []
    assert hygiene.check_blocked_paths([], ["secret.txt"]) != []


def test_fixture_names(tmp_path: Path) -> None:
    write(tmp_path, hygiene.ALLOWED_NAMES_FILE, "# comment\nTest Character One\n@TestAccount\n")
    write(
        tmp_path, "schema/fixtures/a/data.lua", '["name"] = "Test Character One", -- @TestAccount\n'
    )
    files = ["schema/fixtures/a/data.lua", hygiene.ALLOWED_NAMES_FILE]
    assert hygiene.check_fixture_names(tmp_path, files) == []

    write(tmp_path, "schema/fixtures/a/data.lua", '["name"] = "Real Person",\n')
    assert any("Real Person" in p for p in hygiene.check_fixture_names(tmp_path, files))

    write(tmp_path, "schema/fixtures/a/data.lua", "-- owner @SomeRealAccount\n")
    assert any("@SomeRealAccount" in p for p in hygiene.check_fixture_names(tmp_path, files))

    write(tmp_path, "schema/fixtures/a/data.json", '{"name": "Real Person"}')
    assert any(
        "Real Person" in p
        for p in hygiene.check_fixture_names(tmp_path, [*files, "schema/fixtures/a/data.json"])
    )


def test_fixtures_need_an_allow_list(tmp_path: Path) -> None:
    write(tmp_path, "schema/fixtures/a.lua", "x = 1\n")
    assert hygiene.check_fixture_names(tmp_path, ["schema/fixtures/a.lua"]) != []
    assert hygiene.check_fixture_names(tmp_path, ["src/a.lua"]) == []


GOOD_MANIFEST = (
    "## Title: Lib\n## AddOnVersion: 1\n## APIVersion: 101051 101052\n; comment\nLib.lua\n"
)


def test_manifest_ok(tmp_path: Path) -> None:
    write(tmp_path, "src/Lib/Lib.txt", GOOD_MANIFEST)
    write(tmp_path, "src/Lib/Lib.lua", "")
    assert hygiene.check_manifests(tmp_path) == []


@pytest.mark.parametrize(
    ("manifest", "expected"),
    [
        (GOOD_MANIFEST.replace("Lib.lua", "Other.lua"), "Other.lua"),
        (GOOD_MANIFEST.replace("## AddOnVersion: 1\n", ""), "AddOnVersion"),
        (GOOD_MANIFEST.replace("101051 101052", "abc"), "APIVersion"),
        (GOOD_MANIFEST.replace("AddOnVersion: 1", "AddOnVersion: 1.0"), "integer"),
        ("## Title: Lib\n## AddOnVersion: 1\n## APIVersion: 1\n", "no files"),
    ],
)
def test_manifest_problems(tmp_path: Path, manifest: str, expected: str) -> None:
    write(tmp_path, "src/Lib/Lib.txt", manifest)
    write(tmp_path, "src/Lib/Lib.lua", "")
    assert any(expected in p for p in hygiene.check_manifests(tmp_path))


def test_manifest_must_match_folder_name(tmp_path: Path) -> None:
    write(tmp_path, "src/Lib/Other.txt", GOOD_MANIFEST)
    assert any("no manifest named Lib" in p for p in hygiene.check_manifests(tmp_path))


def test_windows_paths_and_language_macros(tmp_path: Path) -> None:
    write(tmp_path, "src/Lib/Lib.txt", GOOD_MANIFEST + "sub\\More.lua\nlang/$(language).lua\n")
    write(tmp_path, "src/Lib/Lib.lua", "")
    write(tmp_path, "src/Lib/sub/More.lua", "")
    assert hygiene.check_manifests(tmp_path) == []
