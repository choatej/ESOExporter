-- ESOExporter.Registry: only a topic of the tree can have an extractor, and only one.

ESO.Load("src/ESOExporter/TopicTree.lua")
local Registry = ESO.Load("src/ESOExporter/Registry.lua")
local TopicTree = ESOExporter.TopicTree

local function smallIndex()
    return TopicTree.Index({
        version = 1,
        nodes = {
            {
                id = "character",
                type = "group",
                label = "Character",
                default = true,
                children = {
                    {
                        id = "character.identity",
                        type = "topic",
                        label = "Identity",
                        default = true,
                        scope = "character",
                        cost = "light",
                    },
                },
            },
        },
    })
end

local function extractor()
    return {}
end

describe("Registry", function()
    it("registers and returns an extractor for a topic", function()
        local registry = Registry.New(smallIndex())
        registry:Register("character.identity", extractor)
        eq(registry:Get("character.identity"), extractor)
    end)

    it("returns nil for a topic with no extractor", function()
        eq(Registry.New(smallIndex()):Get("character.identity"), nil)
    end)

    it("rejects an id that is not in the tree", function()
        raises(function()
            Registry.New(smallIndex()):Register("character.identiy", extractor)
        end, "'character.identiy' is not in the topic tree")
    end)

    it("rejects a group", function()
        raises(function()
            Registry.New(smallIndex()):Register("character", extractor)
        end, "is a group")
    end)

    it("rejects an extractor that is not a function", function()
        raises(function()
            Registry.New(smallIndex()):Register("character.identity", {})
        end, "must be a function")
    end)

    it("rejects a second extractor for the same topic", function()
        local registry = Registry.New(smallIndex())
        registry:Register("character.identity", extractor)
        raises(function()
            registry:Register("character.identity", extractor)
        end, "already has an extractor")
    end)

    it("needs an index", function()
        raises(function()
            Registry.New(nil)
        end, "expected a topic tree index")
    end)

    it("keeps registries apart", function()
        local index = smallIndex()
        local one, two = Registry.New(index), Registry.New(index)
        one:Register("character.identity", extractor)
        eq(two:Get("character.identity"), nil)
    end)
end)
