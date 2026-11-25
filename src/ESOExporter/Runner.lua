-- ESOExporter.Runner
-- Runs extractors and stores their results in the export container (the ESOExporterData global,
-- laid out as in schema/v1/export.schema.json). Pure Lua 5.1: the caller gathers everything that
-- comes from the game (meta, the character, the time) and passes it in, so this is tested offline.
--
--   local container, result = ESOExporter.Runner.Run({
--       index = index,                 -- TopicTree.Index
--       registry = registry,           -- Registry.New
--       ids = { "character.identity" },-- topic ids to run, in order
--       container = ESOExporterData,   -- may be nil; a new table is made
--       meta = { schema = 1, addon = "ESOExporter", ... },
--       character = { id = "8800000000000001", name = "..." }, -- needed for character topics
--       timestamp = 1795000000,
--   })
--   ESOExporterData = container
--
-- Each extractor runs under pcall. One that raises, or returns something other than a table, is
-- listed in result.failed and stores nothing; it never stops the others. A topic with no extractor
-- is listed in result.missing. A topic that runs replaces its earlier entry; topics that do not run
-- keep theirs. Work is synchronous for now; spreading it across frames (LibAsync) comes with the
-- heavy topics.
--
-- result = { stored = { ids }, missing = { ids }, failed = { { id = ..., message = ... } },
--            nodes = n, stringBytes = n, dropped = n }   -- the last three summed over stored entries

local Runner = {}

local function storePath(node, id, character)
    if node.scope == "account" then
        return { "account", "topics", id }
    end
    return { "characters", character.id, "topics", id }
end

--- Run the extractors for `job.ids` and store their entries. Returns the container and a result.
-- Raises only for a malformed job (a programming error), never because an extractor failed.
function Runner.Run(job)
    local index, registry, store = job.index, job.registry, job.store or LibExportStore
    if type(index) ~= "table" or type(registry) ~= "table" or type(job.ids) ~= "table" then
        error("Runner: a job needs index, registry and ids", 2)
    end
    if type(job.meta) ~= "table" then
        error("Runner: a job needs meta", 2)
    end
    if type(store) ~= "table" then
        error("Runner: LibExportStore is not loaded", 2)
    end

    local container = type(job.container) == "table" and job.container or {}
    container.meta = job.meta

    local result = { stored = {}, missing = {}, failed = {}, nodes = 0, stringBytes = 0, dropped = 0 }
    local function fail(id, message)
        result.failed[#result.failed + 1] = { id = id, message = message }
    end

    for _, id in ipairs(job.ids) do
        local node = index.nodes[id]
        local extractor = registry:Get(id)
        if not node or node.type ~= "topic" then
            fail(id, "not a topic in the tree")
        elseif node.scope == "character" and (type(job.character) ~= "table" or not job.character.id) then
            fail(id, "no character to store it under")
        elseif not extractor then
            result.missing[#result.missing + 1] = id
        else
            local ok, data = pcall(extractor, id)
            if not ok then
                fail(id, tostring(data))
            elseif type(data) ~= "table" then
                fail(id, "the extractor returned a " .. type(data) .. ", not a table")
            else
                local entry = store.NewEntry(data, { timestamp = job.timestamp })
                if node.scope == "character" then
                    local characters = container.characters or {}
                    container.characters = characters
                    local character = characters[job.character.id] or { topics = {} }
                    characters[job.character.id] = character
                    character.name = job.character.name
                end
                container = store.Put(container, storePath(node, id, job.character), entry)
                result.stored[#result.stored + 1] = id
                result.nodes = result.nodes + entry.report.nodes
                result.stringBytes = result.stringBytes + entry.report.stringBytes
                result.dropped = result.dropped + entry.report.dropped
            end
        end
    end
    return container, result
end

ESOExporter = ESOExporter or {}
ESOExporter.Runner = Runner
return Runner
