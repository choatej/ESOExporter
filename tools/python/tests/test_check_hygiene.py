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


PLAN = """\
| M0 | Foundation | none | done | [#1](https://github.com/o/r/pull/1) |
| [#1](https://github.com/o/r/pull/1) | Scaffold | M0 | merged |
| [#2](https://github.com/o/r/pull/2) | Docs | open |
| planned | Later work (`feat/x`) | M1 | planned |
"""


def test_plan_rows_are_parsed(tmp_path: Path) -> None:
    write(tmp_path, hygiene.PLAN_FILE, PLAN)
    rows, problems = hygiene.plan_pr_rows(tmp_path)
    assert rows == {1: "merged", 2: "open"}
    assert problems == []


def test_plan_rows_report_bad_rows(tmp_path: Path) -> None:
    write(
        tmp_path,
        hygiene.PLAN_FILE,
        "| [#3](https://github.com/o/r/pull/4) | Mismatch | merged |\n"
        "| [#5](https://github.com/o/r/pull/5) | One | merged |\n"
        "| [#5](https://github.com/o/r/pull/5) | Again | merged |\n"
        "| [#6](https://github.com/o/r/pull/6) | Odd state | in review |\n",
    )
    problems = hygiene.check_plan_rows(tmp_path)
    assert len(problems) == 3
    assert any("links to pull request 4" in p for p in problems)
    assert any("listed twice" in p for p in problems)
    assert any("in review" in p for p in problems)


def test_plan_without_a_plan_file_is_fine(tmp_path: Path) -> None:
    assert hygiene.check_plan_rows(tmp_path) == []


def test_plan_against_github() -> None:
    rows = {1: "merged", 2: "open", 9: "open"}
    actual = {1: "merged", 2: "merged", 3: "open", 4: "closed", 5: "merged"}
    problems = hygiene.compare_plan_with_github(rows, actual)
    assert len(problems) == 4
    assert any("#2 is listed as open but is merged" in p for p in problems)
    assert any("#9 is listed but is not" in p for p in problems)
    assert any("#3 (open) has no row" in p for p in problems)
    assert any("#5 (merged) has no row" in p for p in problems)
    assert not any("#4" in p for p in problems)
