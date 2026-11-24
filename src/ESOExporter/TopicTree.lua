-- ESOExporter.TopicTree
-- Pure functions over the topic tree (schema/v1/tree.json, loaded as TopicTreeData.lua): index it,
-- derive which nodes are effective from the user's overrides, and list the topics to run.
-- No game calls and no dependencies, so it is tested offline. Plain Lua 5.1.
--
-- Terms:
--   node       a group (only gates what is below it) or a topic (a leaf; one stored entry).
--   id         the full dotted path, "character.stats.offense". A topic's id is its storage key.
--   overrides  the user's saved choices: a flat table id -> boolean, holding only the ids whose
--              value differs from the node's default (see Compact). The tree itself is never saved.
--   value      a node's own setting: its override, else its default.
--   effective  a node is effective when its own value and every ancestor's value are true. A
--              child's override survives its parent being switched off; it just stops counting.
--
--   local index = ESOExporter.TopicTree.Index(ESOExporter.TopicTreeData)
--   local effective = ESOExporter.TopicTree.Resolve(index, savedOverrides)
--   for _, id in ipairs(ESOExporter.TopicTree.Topics(index, effective, "character")) do ... end

local TopicTree = {}

local SCOPES = { account = true, character = true }
local COSTS = { light = true, heavy = true }

-- A segment is lower snake_case; an id is segments joined by dots. Keep in step with tree.schema.json.
local SEGMENT = "^[a-z][a-z0-9_]*$"

local function fail(message)
    error("TopicTree: " .. message, 3)
end

--- Build lookup tables from the tree, checking the rules the JSON Schema cannot state.
-- Raises an error on a malformed tree, so a bad tree fails at load and never half-works.
-- Returns { nodes = id -> node, parent = id -> parentId, order = ids depth-first,
-- topics = topic ids depth-first }. Roots have no entry in `parent`.
function TopicTree.Index(tree)
    if type(tree) ~= "table" or type(tree.nodes) ~= "table" then
        fail("expected a tree with a nodes list")
    end
    local index = { nodes = {}, parent = {}, order = {}, topics = {} }

    local function visit(node, parentId)
        local id = node.id
        if type(id) ~= "string" then
            fail("a node has no id")
        end
        local lastSegment = id:match("([^.]+)$")
        if not lastSegment or not lastSegment:match(SEGMENT) then
            fail("bad id '" .. id .. "'")
        end
        local expected = parentId and (parentId .. "." .. lastSegment) or lastSegment
        if id ~= expected then
            fail("id '" .. id .. "' must be its parent's id plus one segment")
        end
        if index.nodes[id] then
            fail("duplicate id '" .. id .. "'")
        end
        if type(node.default) ~= "boolean" then
            fail("'" .. id .. "' needs a boolean default")
        end
        index.nodes[id] = node
        index.parent[id] = parentId
        index.order[#index.order + 1] = id

        if node.type == "group" then
            if type(node.children) ~= "table" or #node.children == 0 then
                fail("group '" .. id .. "' has no children")
            end
            for _, child in ipairs(node.children) do
                visit(child, id)
            end
        elseif node.type == "topic" then
            if node.children ~= nil then
                fail("topic '" .. id .. "' cannot have children")
            end
            if not SCOPES[node.scope] then
                fail("topic '" .. id .. "' has no valid scope")
            end
            if not COSTS[node.cost] then
                fail("topic '" .. id .. "' has no valid cost")
            end
            if id:match("^[^.]+") ~= node.scope then
                fail("topic '" .. id .. "' must sit under its scope '" .. node.scope .. "'")
            end
            index.topics[#index.topics + 1] = id
        else
            fail("'" .. id .. "' is neither a group nor a topic")
        end
    end

    for _, root in ipairs(tree.nodes) do
        visit(root, nil)
    end
    return index
end

--- A node's own setting: its boolean override if there is one, else its default.
-- Raises for an id that is not in the tree.
function TopicTree.Value(index, overrides, id)
    local node = index.nodes[id]
    if not node then
        fail("unknown id '" .. tostring(id) .. "'")
    end
    local override = overrides and overrides[id]
    if type(override) == "boolean" then
        return override
    end
    return node.default
end

--- Effective state of every node: id -> boolean. One pass top-down, because `order` lists a
-- parent before its children. Overrides for ids not in the tree are ignored, so a saved
-- selection that names a topic a later version removed does no harm.
function TopicTree.Resolve(index, overrides)
    local effective = {}
    for _, id in ipairs(index.order) do
        local parentId = index.parent[id]
        local parentOn = parentId == nil or effective[parentId]
        effective[id] = (parentOn and TopicTree.Value(index, overrides, id)) or false
    end
    return effective
end

--- The effective topic ids in tree order, optionally only those of one scope.
function TopicTree.Topics(index, effective, scope)
    local result = {}
    for _, id in ipairs(index.topics) do
        if effective[id] and (scope == nil or index.nodes[id].scope == scope) then
            result[#result + 1] = id
        end
    end
    return result
end

--- Every topic id at or below `id`, in tree order, whatever its state. This is what a command
-- argument such as "character.stats" expands to. Returns nil for an id that is not in the tree.
function TopicTree.TopicsUnder(index, id)
    if not index.nodes[id] then
        return nil
    end
    local result = {}
    local prefix = id .. "."
    for _, topicId in ipairs(index.topics) do
        if topicId == id or topicId:sub(1, #prefix) == prefix then
            result[#result + 1] = topicId
        end
    end
    return result
end

--- A copy of `overrides` holding only what is worth saving: boolean values for ids in the tree
-- that differ from the node's default. Putting a value back to its default therefore removes it.
function TopicTree.Compact(index, overrides)
    local compact = {}
    for id, value in pairs(overrides or {}) do
        local node = index.nodes[id]
        if node and type(value) == "boolean" and value ~= node.default then
            compact[id] = value
        end
    end
    return compact
end

-- ESO loads files as chunks and shares globals between them; the tests load the file directly.
ESOExporter = ESOExporter or {}
ESOExporter.TopicTree = TopicTree
return TopicTree
