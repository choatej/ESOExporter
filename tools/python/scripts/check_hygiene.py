"""Repository hygiene checks, run by CI and by `task hygiene`.

Standard library only, so CI can run it without installing anything. Four checks:

* no tracked file is one that `.gitignore` or the personal-data rules say must stay local;
* fixtures contain only names listed in `schema/fixtures/allowed-names.txt`;
* each add-on folder in `src/` has a manifest of the same name that is well formed and lists
  only files that exist;
* the pull request rows in `docs/PROJECT_PLAN.md` are well formed (link number matches the text,
  no number twice, a known state).

With `--prs` it also compares those rows with GitHub through the `gh` CLI: each row's state must
match the pull request's, and every open or merged pull request must have a row. That needs
network access and a logged-in `gh`, so it is not part of the default run or CI; the `open-pr`
skill runs it (`task hygiene:prs`).

Usage: ``python3 tools/python/scripts/check_hygiene.py [--prs] [repository root]``
"""

from __future__ import annotations

import json
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

PLAN_FILE = "docs/PROJECT_PLAN.md"
PLAN_STATES = {"open", "merged", "closed"}
GITHUB_STATES = {"OPEN": "open", "MERGED": "merged", "CLOSED": "closed"}
# A pull request row: `| [#12](.../pull/12) | title | ... | state |`; state is the last cell.
PLAN_PR_ROW = re.compile(r"^\|\s*\[#(\d+)\]\([^)]*?/pull/(\d+)\)\s*\|.*\|\s*([^|]*?)\s*\|\s*$")

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


def plan_pr_rows(root: Path) -> tuple[dict[int, str], list[str]]:
    """Return {pull request number: state} from the plan, and any problems with the rows."""
    path = root / PLAN_FILE
    if not path.is_file():
        return {}, []
    rows: dict[int, str] = {}
    problems: list[str] = []
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        match = PLAN_PR_ROW.match(line)
        if not match:
            continue
        label = f"{PLAN_FILE}:{line_number}"
        text_number, link_number, state = match.groups()
        number = int(text_number)
        if text_number != link_number:
            problems.append(f"{label}: #{text_number} links to pull request {link_number}")
        if number in rows:
            problems.append(f"{label}: #{number} is listed twice")
        if state not in PLAN_STATES:
            problems.append(
                f"{label}: #{number} has state {state!r}, expected one of {sorted(PLAN_STATES)}"
            )
        rows[number] = state
    return rows, problems


def check_plan_rows(root: Path) -> list[str]:
    return plan_pr_rows(root)[1]


def github_pull_requests(root: Path) -> dict[int, str]:
    result = subprocess.run(
        ["gh", "pr", "list", "--state", "all", "--limit", "500", "--json", "number,state"],
        check=True,
        capture_output=True,
        text=True,
        cwd=root,
    )
    return {item["number"]: GITHUB_STATES[item["state"]] for item in json.loads(result.stdout)}


def compare_plan_with_github(rows: dict[int, str], actual: dict[int, str]) -> list[str]:
    problems = []
    for number, state in sorted(rows.items()):
        if number not in actual:
            problems.append(f"{PLAN_FILE}: #{number} is listed but is not a pull request on GitHub")
        elif actual[number] != state:
            problems.append(
                f"{PLAN_FILE}: #{number} is listed as {state} but is {actual[number]} on GitHub"
            )
    for number, state in sorted(actual.items()):
        if state != "closed" and number not in rows:
            problems.append(
                f"{PLAN_FILE}: #{number} ({state}) has no row; add it to the pull request tables"
            )
    return problems


def check_plan_against_github(root: Path) -> list[str]:
    rows, _ = plan_pr_rows(root)
    try:
        actual = github_pull_requests(root)
    except (OSError, subprocess.CalledProcessError, KeyError, ValueError) as error:
        return [f"could not read pull requests with `gh pr list`: {error}"]
    return compare_plan_with_github(rows, actual)


def run_checks(root: Path, online: bool = False) -> list[str]:
    files = tracked_files(root)
    return [
        *check_blocked_paths(files, ignored_but_tracked(root)),
        *check_fixture_names(root, files),
        *check_manifests(root),
        *check_plan_rows(root),
        *(check_plan_against_github(root) if online else []),
    ]


def main(argv: list[str]) -> int:
    args = [arg for arg in argv[1:] if arg != "--prs"]
    online = len(args) != len(argv) - 1
    root = Path(args[0]) if args else Path(__file__).resolve().parents[3]
    problems = run_checks(root, online=online)
    for problem in problems:
        print(f"hygiene: {problem}", file=sys.stderr)
    if problems:
        print(f"hygiene: {len(problems)} problem(s)", file=sys.stderr)
        return 1
    print("hygiene: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
