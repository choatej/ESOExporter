"""Repository hygiene checks, run by CI and by `task hygiene`.

Standard library only, so CI can run it without installing anything. Three checks:

* no tracked file is one that `.gitignore` or the personal-data rules say must stay local;
* fixtures contain only names listed in `schema/fixtures/allowed-names.txt`;
* each add-on folder in `src/` has a manifest of the same name that is well formed and lists
  only files that exist.

Usage: ``python3 tools/python/scripts/check_hygiene.py [repository root]``
"""

from __future__ import annotations

import re
import subprocess
import sys
from collections.abc import Iterable
from fnmatch import fnmatch
from pathlib import Path

ALLOWED_NAMES_FILE = "schema/fixtures/allowed-names.txt"
FIXTURES_DIR = "schema/fixtures"

# Mirrors the "Personal data" section of .gitignore, in case that file is edited.
BLOCKED_PATTERNS = ("SavedVariables/*", "exports/*", "*_export_*.json")

ACCOUNT_NAME = re.compile(r"(?<![\w.@])@[A-Za-z0-9][A-Za-z0-9_\-]{2,}")
CHARACTER_NAME = re.compile(r"""["']?name["']?\]?\s*[=:]\s*["']([^"']*)["']""")
MANIFEST_KEY = re.compile(r"^##\s*([A-Za-z]+)\s*:\s*(.*?)\s*$")


def git_lines(root: Path, *args: str) -> list[str]:
    result = subprocess.run(
        ["git", "-C", str(root), *args, "-z"], check=True, capture_output=True, text=True
    )
    return [item for item in result.stdout.split("\0") if item]


def tracked_files(root: Path) -> list[str]:
    return git_lines(root, "ls-files")


def ignored_but_tracked(root: Path) -> list[str]:
    return git_lines(root, "ls-files", "-ci", "--exclude-standard")


def check_blocked_paths(files: Iterable[str], ignored_tracked: Iterable[str]) -> list[str]:
    problems = [
        f"{path}: tracked, but .gitignore says it must stay local" for path in ignored_tracked
    ]
    for path in files:
        if any(fnmatch(path, pattern) for pattern in BLOCKED_PATTERNS):
            problems.append(f"{path}: matches a personal-data path and must not be committed")
    return problems


def load_allowed_names(root: Path) -> set[str] | None:
    path = root / ALLOWED_NAMES_FILE
    if not path.is_file():
        return None
    names = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            names.add(line)
    return names


def check_fixture_names(root: Path, files: Iterable[str]) -> list[str]:
    fixtures = [f for f in files if f.startswith(FIXTURES_DIR + "/") and f != ALLOWED_NAMES_FILE]
    if not fixtures:
        return []
    allowed = load_allowed_names(root)
    if allowed is None:
        return [f"{ALLOWED_NAMES_FILE}: missing, but fixtures exist"]
    problems = []
    for path in fixtures:
        try:
            text = (root / path).read_text(encoding="utf-8")
        except UnicodeDecodeError:
            problems.append(f"{path}: not UTF-8 text; fixtures must be text")
            continue
        for name in ACCOUNT_NAME.findall(text) + CHARACTER_NAME.findall(text):
            if name not in allowed:
                problems.append(f"{path}: name {name!r} is not in {ALLOWED_NAMES_FILE}")
    return problems


def parse_manifest(text: str) -> tuple[dict[str, str], list[str]]:
    """Return the `## Key: value` directives and the listed file paths."""
    directives: dict[str, str] = {}
    listed: list[str] = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        match = MANIFEST_KEY.match(line)
        if match:
            directives[match.group(1)] = match.group(2)
        elif not line.startswith(("#", ";")) and "$(" not in line:
            listed.append(line.replace("\\", "/"))
    return directives, listed


def check_manifests(root: Path) -> list[str]:
    problems = []
    src = root / "src"
    if not src.is_dir():
        return problems
    for folder in sorted(p for p in src.iterdir() if p.is_dir()):
        manifests = [folder / f"{folder.name}{ext}" for ext in (".txt", ".addon")]
        found = [m for m in manifests if m.is_file()]
        if not found:
            problems.append(
                f"{folder.relative_to(root)}: no manifest named {folder.name}.txt or .addon"
            )
            continue
        label = found[0].relative_to(root)
        directives, listed = parse_manifest(found[0].read_text(encoding="utf-8"))
        for key in ("Title", "APIVersion", "AddOnVersion"):
            if key not in directives:
                problems.append(f"{label}: missing ## {key}")
        if "APIVersion" in directives and not all(
            part.isdigit() for part in directives["APIVersion"].split()
        ):
            problems.append(
                f"{label}: ## APIVersion must be integers, got {directives['APIVersion']!r}"
            )
        if "AddOnVersion" in directives and not directives["AddOnVersion"].isdigit():
            problems.append(f"{label}: ## AddOnVersion must be an integer")
        if not listed:
            problems.append(f"{label}: lists no files")
        for name in listed:
            if not (folder / name).is_file():
                problems.append(f"{label}: lists {name}, which does not exist")
    return problems


def run_checks(root: Path) -> list[str]:
    files = tracked_files(root)
    return [
        *check_blocked_paths(files, ignored_but_tracked(root)),
        *check_fixture_names(root, files),
        *check_manifests(root),
    ]


def main(argv: list[str]) -> int:
    root = Path(argv[1]) if len(argv) > 1 else Path(__file__).resolve().parents[3]
    problems = run_checks(root)
    for problem in problems:
        print(f"hygiene: {problem}", file=sys.stderr)
    if problems:
        print(f"hygiene: {len(problems)} problem(s)", file=sys.stderr)
        return 1
    print("hygiene: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
