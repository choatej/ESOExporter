# Tests

Offline Lua tests run under LuaJIT, which implements the same Lua 5.1 the game uses.
No game and no dependencies are needed.

```sh
task test              # run every spec
task test -- export    # only specs whose file name contains "export"
task check             # formatting, lint and tests
```

Specs live in `tests/lua/spec/*_spec.lua` and use `describe`, `it`, `before_each`
and the assertions `eq` (deep equality), `truthy`, `falsy` and `raises`. The runner
(`tests/lua/run.lua`) provides them as globals and restores the global table after
each spec, so a spec cannot leak state into the next.

`tests/lua/eso_stubs.lua` holds `Load(path)` for loading project source and any
stand-ins for the game environment. Add a stub only when a module needs one.

Python tests (`task test:python`) live in `tools/python/tests/` and use the standard
`unittest` runner. They need `jsonschema` (`pip install -r tools/python/requirements.txt`).

What cannot be tested offline (the settings panel, the login reminder, real
extraction, the SavedVariables round trip) is verified in game and described in the
pull request.
