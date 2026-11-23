-- Luacheck configuration. ESO runs Lua 5.1.
std = "lua51"
max_line_length = 120

-- Local tooling directories are not part of the project.
-- Fixtures are data files, not code.
exclude_files = { ".claude/", "schema/fixtures/" }

-- The export library publishes one global, as ESO libraries do.
files["src/LibExportStore/"] = {
    globals = { "LibExportStore" },
}

-- Offline tests: the runner (tests/lua/run.lua) provides these globals to every spec.
files["tests/"] = {
    read_globals = {
        "describe",
        "it",
        "before_each",
        "eq",
        "truthy",
        "falsy",
        "raises",
        "ESO",
    },
    ignore = {
        "212", -- unused argument
    },
}
