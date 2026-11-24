-- ESOExporter
-- The game-facing core: builds the topic index and the registry when the file loads (so extractor
-- files listed after this one in the manifest can register), registers the slash commands once
-- the add-on has loaded, and gathers what the runner needs from the game. Everything that can be
-- pure lives in TopicTree, Registry, Runner and Commands.
--
-- Extractor files call ESOExporter.Register("character.identity", function(id) ... end).

local ADDON_NAME = "ESOExporter"

ESOExporter = ESOExporter or {}
local Exporter = ESOExporter

-- Keep in step with ## Version in ESOExporter.txt (a test checks it).
Exporter.NAME = ADDON_NAME
Exporter.VERSION = "0.1.0"
Exporter.SCHEMA = 1

Exporter.index = Exporter.TopicTree.Index(Exporter.TopicTreeData)
Exporter.registry = Exporter.Registry.New(Exporter.index)

--- Register the extractor for a topic id. Raises on a bad id, so a typo fails at load.
function Exporter.Register(id, extractor)
    Exporter.registry:Register(id, extractor)
end

local function Print(line)
    if CHAT_ROUTER then
        CHAT_ROUTER:AddSystemMessage(line)
    else
        d(line)
    end
end

--- The user's saved topic choices. Settings arrive in M4; until then the tree's defaults apply.
local function Overrides()
    return {}
end

local function Meta()
    return {
        schema = Exporter.SCHEMA,
        addon = ADDON_NAME,
        addonVersion = Exporter.VERSION,
        apiVersion = GetAPIVersion(),
        gameVersion = GetESOVersionString(),
        server = GetWorldName(),
    }
end

function Exporter.Save(ids)
    local index = Exporter.index
    local effective = Exporter.TopicTree.Resolve(index, Overrides())
    local selected, problem = Exporter.Commands.SelectTopics(index, effective, ids)
    if not selected then
        Print(problem)
        return
    end
    local container, result = Exporter.Runner.Run({
        index = index,
        registry = Exporter.registry,
        ids = selected,
        container = ESOExporterData,
        meta = Meta(),
        character = { id = GetCurrentCharacterId(), name = GetUnitName("player") },
        timestamp = GetTimeStamp(),
    })
    ESOExporterData = container
    for _, line in ipairs(Exporter.Commands.Summary(result)) do
        Print(line)
    end
end

function Exporter.HandleCommand(text)
    local words = Exporter.Commands.Parse(text)
    if words[1] == "save" then
        local ids = {}
        for i = 2, #words do
            ids[#ids + 1] = words[i]
        end
        Exporter.Save(ids)
    else
        Print(Exporter.Commands.USAGE)
    end
end

local function OnAddOnLoaded(_, name)
    if name ~= ADDON_NAME then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    SLASH_COMMANDS["/esoexport"] = Exporter.HandleCommand
    SLASH_COMMANDS["/eox"] = Exporter.HandleCommand
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
