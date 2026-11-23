# CI and release plan

Status: **draft, for the maintainer's review.** Nothing here is implemented yet. It is
delivered as the pull requests in the table at the end, and the decisions it needs are in
"Open decisions". Anything marked *(verify)* is an assumption to check before relying on it.

## Principles

- `main` is protected and squash-only, so **the pull request title is the commit**
  that release tooling reads. Titles are Conventional Commits and CI enforces it.
- Versions come from commits (semver), never from hand edits. A person decides *when*
  to release by merging a release pull request; nothing publishes on its own.
- One build produces every artifact. Publishing steps only upload what that build made.
- Workflows use least privilege, pin third-party actions to commit SHAs (Dependabot
  keeps them current), and never use `pull_request_target`. Fixtures and
  SavedVariables from outside contributors are untrusted data.

## Continuous integration

A single workflow, `ci.yml`, on `pull_request` and on pushes to `main`. Jobs are
independent so a failure names its cause. Their names become the required status checks
on `main` (added to branch protection after the first green run).

| Job | Runs | Notes |
|---|---|---|
| `pr-title` | Conventional Commits check on the PR title | Allowed types: `feat fix perf revert docs chore test refactor build ci style`. Scopes: `addon lib schema python web tools ci docs release` |
| `lua` | StyLua check, Luacheck, offline specs under **LuaJIT and stock Lua 5.1** | Both, because they differ (see `CLAUDE.md`). Same commands as `task check` |
| `python` | `uv sync --locked`, Black check, Ruff, Pyrefly, pytest with coverage | Matrix: Python 3.11 and 3.13 (lowest and newest supported) on Linux; 3.12 on Windows and macOS because the tool is a desktop utility |
| `package` | Build the add-on zip and the Python wheel and sdist, and check them | Catches packaging breakage before a release. Uploads them as workflow artifacts (7 days) |
| `repo-hygiene` | Manifest checks, personal-data guard | See below |

**Manifest checks** (a script, unit tested): each add-on folder name equals its
manifest file name; every file listed in a manifest exists; `## APIVersion` is present
and not older than a floor kept in one place; `## AddOnVersion` matches the version
derived from `## Version` (below); `## DependsOn` names are known.

**Personal-data guard**: fails if a tracked file matches paths `.gitignore` already
blocks, or if a fixture contains an `@account` name or a character name not on an
allow list of invented names. This is a backstop for the scrubbing rule, not a
replacement for it.

What CI cannot do: run the game. In-game behaviour stays a manual check, recorded in
the PR template with the game version.

Also configured with CI: Dependabot for GitHub Actions and for the uv project
(weekly, grouped), and a CI badge in the README, which `CLAUDE.md` allows once a
workflow exists.

An optional scheduled job (weekly) could open an issue when the live game API version
moves past the one in the manifests, so the bump is not forgotten *(verify where the
live version can be read reliably; ESOUI does not publish it as an API)*.

## Versioning

- **Semantic Versioning, driven by Conventional Commits** through
  [release-please](https://github.com/googleapis/release-please) *(its current
  behaviour to be confirmed when it is set up)*. It reads the squash commits on
  `main`, keeps a standing **release pull request** up to date with the next version
  and changelog, and on merge creates the tag and the GitHub release.
- Bump rules: `feat` is a minor bump, `fix`, `perf` and `revert` are patch bumps, a
  `!` or a `BREAKING CHANGE:` footer is a major bump. Other types do not release.
  While the version is 0.x, breaking changes bump the minor and features bump the
  patch (`bump-minor-pre-major`, `bump-patch-for-minor-pre-major`), so 1.0.0 is a
  deliberate decision made by setting it explicitly.
- A schema change that breaks readers (new `meta.schema`) is a breaking change and is
  written as one.
- **One repository version** for the add-on, the data add-on, `LibExportStore`, and the
  Python and web tools, tagged `vX.Y.Z`. They ship together, so one number is the least
  confusing for users. If `LibExportStore` is published on its own, it moves to a
  second release-please package with its own tags.
- The first release is **0.1.0** (set with `initial-version`, since release-please
  would otherwise start at 1.0.0), cut when milestone M8 is met. Until then the release
  pull request simply stays open and accumulates.
- **Where the version lives.** The release pull request edits these, using
  `x-release-please-version` markers where the format allows:
  - each add-on manifest's `## Version: X.Y.Z`;
  - `tools/python/pyproject.toml` (`version`) and the lock file;
  - the web tool's version constant, when it exists;
  - `CHANGELOG.md` (generated; see Open decisions).
- **`## AddOnVersion`** is an integer the game compares, so it must grow with the
  semver. Derive it as `major * 10000 + minor * 100 + patch` (0.1.0 is 100, 1.2.3 is
  10203). A script computes it, the `repo-hygiene` job checks the manifests agree, and
  the release pull request includes the updated value.
- `## APIVersion` is not part of semver. It is bumped by a `fix(addon):` or
  `chore(addon):` commit after checking the changelog for the new game update, and
  the game version it was verified on goes in the PR.

## Release process

1. Work merges to `main` through squash-merged PRs with conventional titles.
2. release-please keeps the release PR current. Reviewing it is the changelog review.
3. The maintainer merges the release PR. That creates tag `vX.Y.Z` and the GitHub
   release (draft until the artifacts are attached, then published).
4. In the **same workflow run** (events created with the default token do not start
   other workflows), a `release` job builds and attaches the artifacts, then the
   publish jobs run.
5. A release candidate (`vX.Y.Z-rc.N`) can be cut the same way and is marked
   pre-release; it is not published to ESOUI or PyPI.

Hotfixes are the same flow: a `fix:` commit, then the release PR.

## Artifacts on each GitHub release

| Artifact | What | Why |
|---|---|---|
| `ESOExporter-X.Y.Z.zip` | The add-on package: top-level folders `ESOExporter/`, `ESOExporterData/` and `LibExportStore/`, each with its manifest, plus `LICENSE` and the changelog inside the main folder | This is what players unzip into `Documents/Elder Scrolls Online/live/AddOns`, and what ESOUI hosts. Folder names equal manifest names. No `.git`, tests, docs or tooling |
| `esoexporter-X.Y.Z-py3-none-any.whl` and `esoexporter-X.Y.Z.tar.gz` | The Python post-processor | Same files that go to PyPI |
| `esoexporter-viewer-X.Y.Z.html` | The default post-processor as one self-contained file | Open it in a browser, offline, nothing to install |
| `SHA256SUMS` | Checksums of all of the above | Verification |
| Build provenance attestations | GitHub artifact attestations for each file | Proves the files came from this workflow |
| Release notes | The changelog section for the version | From release-please |

GitHub also attaches the source archives automatically.

Libraries the add-on depends on (LibAsync, LibAddonMenu-2.0, and so on) are **not
bundled**; they are declared in `## DependsOn` and installed from ESOUI like any other
add-on dependency. `LibExportStore` is bundled as a sibling folder until it has its own
listing.

## Distribution channels

| Channel | What goes there | How |
|---|---|---|
| GitHub Releases | Everything above | Automatic, from the release workflow |
| ESOUI | `ESOExporter-X.Y.Z.zip`, with the changelog and the supported API version | The first listing is created by hand (it needs the listing id and description). Updates are uploaded by hand at first; automate through ESOUI's author API token if it supports uploads *(verify)*. Minion and other managers read ESOUI, so this is how most players update |
| PyPI | The wheel and sdist as `esoexporter` (the name was unregistered on 2026-11-22) | **Trusted publishing** (OIDC), from a protected `pypi` environment that needs the maintainer's approval. No API tokens stored |
| GitHub Pages | A hosted copy of the web tool, `index.html` | Convenience only; the file still works offline and never sends data anywhere. Optional |

## Post-processor packaging

**Python tool.** A standard wheel and sdist built by `uv build`, published to PyPI and
attached to the release. It installs as a command with `uv tool install esoexporter`
or `pipx install esoexporter`, and runs without installing through `uvx esoexporter`.
The command-line entry point (`[project.scripts]`) arrives with milestone M5. It
declares `requires-python >=3.11` and depends only on `jsonschema`. A standalone
executable (PyInstaller or similar) is not planned: the audience can run Python, and
frozen binaries add platform builds and antivirus noise. Revisit if users ask.

**Default (web) tool.** One self-contained HTML file with its script, styles and the
schema inlined, no external requests, no network access. This matches the
architecture: the SavedVariables file never leaves the machine, and a single file can
be saved, emailed or opened from a USB stick, including on a Steam Deck. A build
step (`tools/web`) inlines the sources into that file; a CI test loads the built file
in a headless browser against the shared fixtures and compares the normalized output
with the Python tool's. A Content-Security-Policy in the file forbids network access,
so the claim is enforced rather than promised.

Both consume `schema/v1/export.schema.json` from the same tag, so they cannot drift
from the add-on they were released with.

## Security and supply chain

- Workflow permissions default to `contents: read`; jobs request more only where
  needed (`contents: write` and `id-token: write` for the release job, `pages: write`
  for Pages).
- Third-party actions are pinned to full commit SHAs. `uv.lock` is committed and CI
  uses `--locked`.
- The release job builds from the tagged commit in a clean runner. Attestations and
  `SHA256SUMS` let anyone check a download.
- Release-please opens its pull requests with the default token, and pull requests
  created that way do not trigger CI, so required checks would never run on them. Use
  a fine-grained personal access token or a small GitHub App for that one step.

## Open decisions

1. **Changelog.** release-please generates `CHANGELOG.md` from commit messages, which
   replaces the hand-kept `[Unreleased]` section and the PR-template checkbox for it.
   Recommendation: switch to the generated file; PR titles then carry the user-facing
   wording, so write them for users. (Alternative: keep the manual changelog and use a
   different tool only for version numbers.)
2. **One version or per-component versions.** Recommendation: one, as above.
3. **Release PR token.** A fine-grained PAT, or a GitHub App. Recommendation: PAT first
   (less to set up), App if it is ever shared with other maintainers.
4. **Python matrix.** Which versions and operating systems to support. Recommendation
   as in the table.
5. **ESOUI automation.** Manual uploads first; revisit when the API is checked.
6. **GitHub Pages copy** of the web tool: wanted or not.
7. **Release candidates** for beta testers: wanted or not.

## Pull requests

These are rows of the pull request roadmap in [PROJECT_PLAN.md](PROJECT_PLAN.md), which
is where their numbers and links go once they are opened.

| Branch | Title | Milestone | State |
|---|---|---|---|
| `ci/workflow` | CI workflow, PR title check, Dependabot, branch-protection checks, README badge | housekeeping | planned |
| `feat/packaging` | Add-on packaging and manifest check scripts, with tests | M8 | planned |
| `ci/release-please` | release-please config, version markers, `AddOnVersion` derivation, changelog switch | M8 | planned |
| `ci/release-artifacts` | Release job: build, checksums, attestations, upload; PyPI trusted publishing | M8 | planned |
| `feat/web-packaging` | Single-file build and headless browser test of the web tool | M6 | planned |

The CI workflow is independent of the product work and worth doing before more code
lands, so every later pull request is checked. The packaging and release rows can follow
any time before M8.
