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

-- The add-on publishes one global namespace, as ESO add-ons do, and writes the export global
-- (owned by the ESOExporterData add-on) and its slash commands. The rest are game globals it reads.
files["src/ESOExporter/"] = {
    globals = { "ESOExporter", "ESOExporterData", "SLASH_COMMANDS" },
    read_globals = {
        "LibExportStore",
        "EVENT_MANAGER",
        "EVENT_ADD_ON_LOADED",
        "CHAT_ROUTER",
        "d",
        "GetAPIVersion",
        "GetESOVersionString",
        "GetWorldName",
        "GetCurrentCharacterId",
        "GetUnitName",
        "GetTimeStamp",
        "GetUnitRaceId",
        "GetUnitClassId",
        "GetUnitGender",
        "GetUnitAlliance",
        "GetUnitLevel",
        "GetPlayerChampionPointsEarned",
    },
}

-- Offline tests: the runner (tests/lua/run.lua) provides these globals to every spec. The add-on
-- spec resets the add-on's globals and reads the game stand-ins from eso_stubs.lua.
files["tests/"] = {
    globals = { "ESOExporter", "ESOExporterData" },
    read_globals = {
        "SLASH_COMMANDS",
        "EVENT_ADD_ON_LOADED",
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
