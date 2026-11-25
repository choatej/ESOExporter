-- ESOExporter.Commands: parsing, topic selection and the chat summary.

ESO.Load("src/ESOExporter/TopicTreeData.lua")
ESO.Load("src/ESOExporter/TopicTree.lua")
local Commands = ESO.Load("src/ESOExporter/Commands.lua")
local TopicTree = ESOExporter.TopicTree
local index = TopicTree.Index(ESOExporter.TopicTreeData)
local defaults = TopicTree.Resolve(index, {})

local function contains(list, value)
    for _, item in ipairs(list) do
        if item == value then
            return true
        end
    end
    return false
end

describe("Commands.Parse", function()
    it("splits on whitespace and lower-cases", function()
        eq(Commands.Parse("  SAVE  Character.Stats\taccount "), { "save", "character.stats", "account" })
        eq(Commands.Parse(""), {})
        eq(Commands.Parse(nil), {})
    end)
end)

describe("Commands.SelectTopics", function()
    it("runs the effective topics when no id is given", function()
        local selected = Commands.SelectTopics(index, defaults, {})
        eq(selected, TopicTree.Topics(index, defaults))
        truthy(contains(selected, "character.identity"))
        falsy(contains(selected, "account.achievements"), "a heavy topic is off by default")
    end)

    it("expands a group, keeping tree order and dropping repeats", function()
        local selected = Commands.SelectTopics(index, defaults, { "character.stats.offense", "character.stats" })
        eq(selected, TopicTree.TopicsUnder(index, "character.stats"))
    end)

    it("runs a named topic even when it is switched off", function()
        eq(Commands.SelectTopics(index, defaults, { "account.achievements" }), { "account.achievements" })
    end)

    it("reports an unknown id", function()
        local selected, problem = Commands.SelectTopics(index, defaults, { "character.nope" })
        eq(selected, nil)
        eq(problem, "ESOExporter: 'character.nope' is not a topic or group.")
    end)
end)

describe("Commands.StartLine", function()
    it("says how many topics will be saved", function()
        eq(Commands.StartLine(1), "ESOExporter: saving 1 topic in the background...")
        eq(Commands.StartLine(12), "ESOExporter: saving 12 topics in the background...")
    end)
end)

describe("Commands.Summary", function()
    it("says what was saved and where the file appears", function()
        local lines = Commands.Summary({ stored = { "a.b" }, missing = {}, failed = {}, dropped = 0 })
        eq(#lines, 1)
        truthy(lines[1]:find("^ESOExporter: saved 1 topic%."), lines[1])
        truthy(lines[1]:find("/reloadui", 1, true))
    end)

    it("counts missing extractors, failures and dropped values, and lists each failure", function()
        local lines = Commands.Summary({
            stored = {},
            missing = { "a.b", "a.c" },
            failed = { { id = "a.d", message = "boom" } },
            dropped = 3,
        })
        truthy(
            lines[1]:find("saved 0 topics; 2 topics have no extractor yet; 1 topic failed; 3 values dropped.", 1, true),
            lines[1]
        )
        eq(lines[2], "ESOExporter: a.d failed: boom")
    end)
end)
