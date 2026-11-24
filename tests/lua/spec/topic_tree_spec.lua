-- ESOExporter.TopicTree: indexing, validation, gate semantics and override handling. The real tree
-- (TopicTreeData.lua, generated from schema/v1/tree.json) is checked against the same rules.

local TopicTree = ESO.Load("src/ESOExporter/TopicTree.lua")
local RealData = ESO.Load("src/ESOExporter/TopicTreeData.lua")

local function topic(id, scope, default, cost)
    return { id = id, type = "topic", label = id, default = default, scope = scope, cost = cost or "light" }
end

local function group(id, default, children)
    return { id = id, type = "group", label = id, default = default, children = children }
end

--- A small tree: two scopes, a nested group, and one heavy topic that is off by default.
local function smallTree()
    return {
        version = 1,
        nodes = {
            group("account", true, {
                topic("account.currency", "account", true),
                topic("account.achievements", "account", false, "heavy"),
            }),
            group("character", true, {
                topic("character.identity", "character", true),
                group("character.stats", true, {
                    topic("character.stats.offense", "character", true),
                    topic("character.stats.defense", "character", true),
                }),
            }),
        },
    }
end

local function ids(list)
    return table.concat(list, ",")
end

describe("TopicTree.Index", function()
    it("lists nodes parent before child, and topics in tree order", function()
        local index = TopicTree.Index(smallTree())
        eq(
            ids(index.order),
            "account,account.currency,account.achievements,character,character.identity,"
                .. "character.stats,character.stats.offense,character.stats.defense"
        )
        eq(
            ids(index.topics),
            "account.currency,account.achievements,character.identity,character.stats.offense,"
                .. "character.stats.defense"
        )
        eq(index.parent["character.stats.offense"], "character.stats")
        eq(index.parent["character"], nil)
    end)

    it("rejects a malformed tree", function()
        local cases = {
            ["not a tree"] = function()
                return {}
            end,
            ["duplicate id"] = function()
                local tree = smallTree()
                tree.nodes[1].children[2].id = "account.currency"
                return tree
            end,
            ["id that is not its parent's plus one segment"] = function()
                local tree = smallTree()
                tree.nodes[1].children[1].id = "account.x.currency"
                return tree
            end,
            ["root with a dotted id"] = function()
                local tree = smallTree()
                tree.nodes[1].id = "a.account"
                return tree
            end,
            ["segment in camelCase"] = function()
                local tree = smallTree()
                tree.nodes[1].children[1].id = "account.craftBag"
                return tree
            end,
            ["default that is not a boolean"] = function()
                local tree = smallTree()
                tree.nodes[1].children[1].default = "yes"
                return tree
            end,
            ["topic with children"] = function()
                local tree = smallTree()
                tree.nodes[1].children[1].children = { topic("account.currency.x", "account", true) }
                return tree
            end,
            ["group without children"] = function()
                local tree = smallTree()
                tree.nodes[1].children = {}
                return tree
            end,
            ["topic without a scope"] = function()
                local tree = smallTree()
                tree.nodes[1].children[1].scope = nil
                return tree
            end,
            ["topic with an unknown cost"] = function()
                local tree = smallTree()
                tree.nodes[1].children[1].cost = "medium"
                return tree
            end,
            ["topic outside its scope's root"] = function()
                local tree = smallTree()
                tree.nodes[1].children[1].scope = "character"
                return tree
            end,
            ["node of another type"] = function()
                local tree = smallTree()
                tree.nodes[1].children[1].type = "leaf"
                return tree
            end,
        }
        for name, build in pairs(cases) do
            local ok = pcall(TopicTree.Index, build())
            if ok then
                error("accepted a malformed tree: " .. name)
            end
        end
    end)
end)

describe("TopicTree.Resolve", function()
    local index

    before_each(function()
        index = TopicTree.Index(smallTree())
    end)

    it("uses the defaults when there are no overrides", function()
        local effective = TopicTree.Resolve(index, nil)
        eq(effective["account"], true)
        eq(effective["account.currency"], true)
        eq(effective["account.achievements"], false)
        eq(effective["character.stats.offense"], true)
    end)

    it("lets a topic be switched on or off on its own", function()
        local effective = TopicTree.Resolve(index, {
            ["account.achievements"] = true,
            ["character.stats.defense"] = false,
        })
        eq(effective["account.achievements"], true)
        eq(effective["character.stats.defense"], false)
        eq(effective["character.stats.offense"], true)
    end)

    it("turns everything below a group off with the group", function()
        local effective = TopicTree.Resolve(index, { ["character.stats"] = false })
        eq(effective["character.stats"], false)
        eq(effective["character.stats.offense"], false)
        eq(effective["character.stats.defense"], false)
        eq(effective["character.identity"], true)
    end)

    it("keeps a child's override while its parent is off, and honors it when the parent returns", function()
        local overrides = { ["character.stats"] = false, ["character.stats.defense"] = false }
        eq(TopicTree.Resolve(index, overrides)["character.stats.offense"], false)
        overrides["character.stats"] = nil
        local effective = TopicTree.Resolve(index, overrides)
        eq(effective["character.stats.offense"], true)
        eq(effective["character.stats.defense"], false)
    end)

    it("does not switch a child on when only the child is overridden under an off parent", function()
        local effective = TopicTree.Resolve(index, { ["character"] = false, ["character.identity"] = true })
        eq(effective["character.identity"], false)
    end)

    it("ignores overrides for ids that are not in the tree and values that are not booleans", function()
        local effective = TopicTree.Resolve(index, { ["character.removed"] = true, ["account.currency"] = "no" })
        eq(effective["character.removed"], nil)
        eq(effective["account.currency"], true)
    end)
end)

describe("TopicTree.Topics", function()
    local index

    before_each(function()
        index = TopicTree.Index(smallTree())
    end)

    it("lists only effective topics, never groups", function()
        local effective = TopicTree.Resolve(index, nil)
        eq(
            ids(TopicTree.Topics(index, effective)),
            "account.currency,character.identity,character.stats.offense,character.stats.defense"
        )
    end)

    it("filters by scope", function()
        local effective = TopicTree.Resolve(index, { ["account.achievements"] = true })
        eq(ids(TopicTree.Topics(index, effective, "account")), "account.currency,account.achievements")
        eq(
            ids(TopicTree.Topics(index, effective, "character")),
            "character.identity,character.stats.offense,character.stats.defense"
        )
    end)
end)

describe("TopicTree.TopicsUnder", function()
    local index

    before_each(function()
        index = TopicTree.Index(smallTree())
    end)

    it("expands a group to its topics whatever their state", function()
        eq(ids(TopicTree.TopicsUnder(index, "account")), "account.currency,account.achievements")
        eq(ids(TopicTree.TopicsUnder(index, "character.stats")), "character.stats.offense,character.stats.defense")
    end)

    it("returns a topic for its own id", function()
        eq(ids(TopicTree.TopicsUnder(index, "character.identity")), "character.identity")
    end)

    it("does not match a sibling that shares a prefix", function()
        local tree = smallTree()
        table.insert(tree.nodes[2].children, topic("character.stats_extra", "character", true))
        local withSibling = TopicTree.Index(tree)
        eq(
            ids(TopicTree.TopicsUnder(withSibling, "character.stats")),
            "character.stats.offense,character.stats.defense"
        )
    end)

    it("returns nil for an unknown id", function()
        eq(TopicTree.TopicsUnder(index, "character.nothing"), nil)
    end)
end)

describe("TopicTree.Compact", function()
    local index

    before_each(function()
        index = TopicTree.Index(smallTree())
    end)

    it("keeps only values that differ from the default", function()
        local compact = TopicTree.Compact(index, {
            ["account.currency"] = true, -- the default
            ["account.achievements"] = true, -- differs
            ["character.stats.offense"] = false, -- differs
        })
        eq(compact["account.currency"], nil)
        eq(compact["account.achievements"], true)
        eq(compact["character.stats.offense"], false)
    end)

    it("drops unknown ids and non-boolean values, and does not change its input", function()
        local overrides = { ["gone.topic"] = true, ["account.achievements"] = 1 }
        local compact = TopicTree.Compact(index, overrides)
        eq(next(compact), nil)
        eq(overrides["gone.topic"], true)
    end)

    it("round-trips: resolving the compact form gives the same effective state", function()
        local overrides =
            { ["account.achievements"] = true, ["character.stats"] = false, ["character.identity"] = true }
        eq(
            ids(TopicTree.Topics(index, TopicTree.Resolve(index, TopicTree.Compact(index, overrides)))),
            ids(TopicTree.Topics(index, TopicTree.Resolve(index, overrides)))
        )
    end)
end)

describe("the real topic tree", function()
    local index = TopicTree.Index(RealData)

    it("passes the loader's checks", function()
        truthy(#index.topics > 0)
    end)

    it("is published for the game as ESOExporter.TopicTree and ESOExporter.TopicTreeData", function()
        eq(ESOExporter.TopicTree, TopicTree)
        eq(ESOExporter.TopicTreeData, RealData)
    end)

    it("turns heavy topics off by default and light topics on", function()
        local effective = TopicTree.Resolve(index, nil)
        for _, id in ipairs(index.topics) do
            eq(effective[id], index.nodes[id].cost == "light")
        end
    end)

    it("covers every topic of the hand-built fixture that is not synthetic", function()
        local chunk = assert(loadfile(ESO.root .. "/schema/fixtures/hand-built/ESOExporterData.lua"))
        local env = {}
        setfenv(chunk, env)
        chunk()
        local function check(scope, topics)
            for id in pairs(topics) do
                if id:sub(1, 8) ~= "fixture." then
                    truthy(index.nodes[id])
                    eq(index.nodes[id].type, "topic")
                    eq(index.nodes[id].scope, scope)
                end
            end
        end
        check("account", env.ESOExporterData.account.topics)
        for _, character in pairs(env.ESOExporterData.characters) do
            check("character", character.topics)
        end
    end)

    it("expands a group the way a command argument would", function()
        eq(
            ids(TopicTree.TopicsUnder(index, "character.champion_points")),
            "character.champion_points.assigned,character.champion_points.slotted"
        )
    end)
end)
