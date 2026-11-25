-- Helpers for loading project source into a test, and stand-ins for the parts of the ESO
-- environment that code touches at load time. Add a stub here when a module needs one, and
-- keep each stub as small as the module's use of it. Pure code (such as the export library)
-- needs none.

local Stubs = {}

-- Directory of the repository root, set by the runner.
Stubs.root = "."

-- Load one source file (path relative to the repository root) into the current globals and
-- return whatever the chunk returns.
function Stubs.Load(relativePath)
    local chunk, err = loadfile(Stubs.root .. "/" .. relativePath)
    if not chunk then
        error("cannot load " .. relativePath .. ": " .. tostring(err), 2)
    end
    return chunk()
end

-- Load every file an add-on's manifest lists, in manifest order, the way the game does.
-- `folder` is the add-on folder relative to the repository root, e.g. "src/ESOExporter".
function Stubs.LoadAddOn(folder)
    local name = folder:match("([^/]+)$")
    local manifest = assert(io.open(Stubs.root .. "/" .. folder .. "/" .. name .. ".txt", "r"))
    local text = manifest:read("*a")
    manifest:close()
    for line in text:gmatch("[^\r\n]+") do
        local file = line:match("^%s*(.-)%s*$")
        if file ~= "" and not file:match("^[#;]") then
            Stubs.Load(folder .. "/" .. file)
        end
    end
    return text
end

-- Install the game globals ESOExporter.lua uses. Returns a handle: `fire(event, ...)` calls the
-- handlers registered for an event, and `printed` collects chat lines. `values` overrides the
-- answers the game functions give.
function Stubs.Game(values)
    values = values or {}
    local game = { handlers = {}, printed = {} }
    function game.fire(event, ...)
        for _, handler in pairs(game.handlers[event] or {}) do
            handler(event, ...)
        end
    end

    _G.EVENT_ADD_ON_LOADED = 65536
    _G.EVENT_MANAGER = {
        RegisterForEvent = function(_, namespace, event, handler)
            game.handlers[event] = game.handlers[event] or {}
            game.handlers[event][namespace] = handler
        end,
        UnregisterForEvent = function(_, namespace, event)
            if game.handlers[event] then
                game.handlers[event][namespace] = nil
            end
        end,
    }
    _G.SLASH_COMMANDS = {}
    _G.CHAT_ROUTER = {
        AddSystemMessage = function(_, line)
            game.printed[#game.printed + 1] = line
        end,
    }
    _G.GetAPIVersion = function()
        return values.apiVersion or 101051
    end
    _G.GetESOVersionString = function()
        return values.gameVersion or "eso.live.12.1.7.3318083"
    end
    _G.GetWorldName = function()
        return values.server or "NA Megaserver"
    end
    _G.GetCurrentCharacterId = function()
        return values.characterId or "4500000000000001"
    end
    _G.GetUnitName = function()
        return values.characterName or "Test Character One"
    end
    _G.GetTimeStamp = function()
        return values.timestamp or 1795000000
    end
    return game
end

return Stubs
