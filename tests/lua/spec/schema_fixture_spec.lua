-- The hand-built schema fixture, checked from the Lua side: it loads the way the game loads a
-- SavedVariables file, no string is long enough for the game to drop, and each entry's report
-- matches what LibExportStore.Sanitize says about the entry's data. (JSON Schema validation runs
-- in Python: `task test:python`.)

local Lib = ESO.Load("src/LibExportStore/LibExportStore.lua")

local function loadFixture()
    local chunk = assert(loadfile(ESO.root .. "/schema/fixtures/hand-built/ESOExporterData.lua"))
    local env = {}
    setfenv(chunk, env)
    chunk()
    return env.ESOExporterData
end

local function forEachEntry(data, fn)
    for topic, entry in pairs(data.account.topics) do
        fn("account." .. topic, entry)
    end
    for id, character in pairs(data.characters) do
        for topic, entry in pairs(character.topics) do
            fn(id .. "." .. topic, entry)
        end
    end
end

local function longestString(value)
    local longest = 0
    if type(value) == "string" then
        return #value
    elseif type(value) == "table" then
        for k, v in pairs(value) do
            longest = math.max(longest, longestString(k), longestString(v))
        end
    end
    return longest
end

describe("schema fixture", function()
    it("loads as a single ESOExporterData global of schema version 1", function()
        local data = loadFixture()
        eq(data.meta.schema, 1)
        truthy(data.account.topics["account.currency"])
        truthy(data.characters["4500000000000001"].topics["character.identity"])
    end)

    it("holds no string the game would drop", function()
        truthy(longestString(loadFixture()) < 2000)
    end)

    it("is summarized by the library", function()
        local summary = Lib.Summarize(loadFixture())
        eq(summary.entries, 5)
        eq(summary.oldest, 1795000000)
        eq(summary.newest, 1795000060)
        eq(summary.dropped, 1)
    end)

    it("has reports that match the data they describe", function()
        local fields = { "tables", "strings", "longStrings", "numbers", "booleans", "nodes", "stringBytes" }
        forEachEntry(loadFixture(), function(label, entry)
            eq(entry.report.dropped, #entry.report.droppedList, label .. " dropped count")
            -- Dropped values are gone from the data but were counted, so only compare the rest.
            if entry.report.dropped == 0 then
                local _, report = Lib.Sanitize(Lib.Restore(entry.data), { maxString = 60 })
                for _, field in ipairs(fields) do
                    eq(entry.report[field], report[field], label .. " report." .. field)
                end
            end
        end)
    end)

    it("rejoins the long string exactly", function()
        local entry = loadFixture().characters["4500000000000002"].topics["fixture.long_text"]
        eq(
            Lib.Restore(entry.data).text,
            "First line of a synthetic long string.\nSecond line, kept whole when it fits.\nThird line ends the text.\n"
        )
    end)
end)
