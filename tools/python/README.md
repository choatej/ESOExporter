# esoexporter (Python post-processor)

Reads an ESOExporter SavedVariables file outside the game, validates it against the
schema in `../../schema`, and (in later steps) writes normalized JSON and Markdown.

So far it holds a safe SavedVariables reader (`esoexporter.luadata`) and the schema
tests. It is a [uv](https://docs.astral.sh/uv/) project.

```sh
uv sync                      # create .venv and install runtime and dev dependencies
uv run pytest                # tests (add --cov=esoexporter for coverage)
uv run ruff check            # lint
uv run black --check .       # formatting (`uv run black .` applies it)
uv run pyrefly check         # type check
```

From the repository root, `task python:check` runs all of the above.
