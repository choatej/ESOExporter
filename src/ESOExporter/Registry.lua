-- ESOExporter.Registry
-- Maps topic ids to the extractors that produce them. Pure Lua 5.1, no game calls.
--
-- A registry is checked against the topic tree: only a topic (a leaf of schema/v1/tree.json) can
-- have an extractor, and only one. Anything else is a programming error and raises at load time,
-- so a typo in an extractor file fails loudly instead of silently never running.
--
--   local registry = ESOExporter.Registry.New(index)        -- index from TopicTree.Index
--   registry:Register("character.identity", function(id) return { ... } end)
--   local extractor = registry:Get("character.identity")
--
-- An extractor is called with its topic id and returns a plain table of raw values (see "Raw data"
-- in docs/ARCHITECTURE.md). The runner calls it under pcall.

local Registry = {}
Registry.__index = Registry

--- A new, empty registry for the tree described by `index`.
function Registry.New(index)
    if type(index) ~= "table" or type(index.nodes) ~= "table" then
        error("Registry: expected a topic tree index", 2)
    end
    return setmetatable({ index = index, extractors = {} }, Registry)
end

--- Register the extractor for topic `id`. Raises if `id` is not a topic in the tree, if
-- `extractor` is not a function, or if the topic already has one.
function Registry:Register(id, extractor)
    local node = self.index.nodes[id]
    if not node then
        error("Registry: '" .. tostring(id) .. "' is not in the topic tree", 2)
    end
    if node.type ~= "topic" then
        error("Registry: '" .. id .. "' is a group; only a topic can have an extractor", 2)
    end
    if type(extractor) ~= "function" then
        error("Registry: the extractor for '" .. id .. "' must be a function", 2)
    end
    if self.extractors[id] then
        error("Registry: '" .. id .. "' already has an extractor", 2)
    end
    self.extractors[id] = extractor
end

--- The extractor registered for `id`, or nil.
function Registry:Get(id)
    return self.extractors[id]
end

ESOExporter = ESOExporter or {}
ESOExporter.Registry = Registry
return Registry
