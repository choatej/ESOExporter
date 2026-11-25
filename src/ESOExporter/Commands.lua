-- ESOExporter.Commands
-- The pure half of the slash commands: parse the text, choose the topics, word the replies.
-- ESOExporter.lua registers /esoexport and its alias /eox and does the game calls.
-- Commands are added as they are needed; so far there is only `save`.
--
--   /esoexport save                   every effective topic (the tree's defaults, until settings exist)
--   /esoexport save character.stats   every topic under a group, or one topic, whatever its setting

local Commands = {}

Commands.USAGE = "Usage: /esoexport save [topic or group id ...]  (alias /eox)"

--- Split the command text into lower-case words.
function Commands.Parse(text)
    local words = {}
    for word in tostring(text or ""):gmatch("%S+") do
        words[#words + 1] = word:lower()
    end
    return words
end

--- The topic ids a `save` runs, in tree order.
-- With no ids: the effective topics. With ids: every topic at or below each one, whether it is
-- switched on or not, because naming it is asking for it. Returns nil and a message when an id
-- is not in the tree.
function Commands.SelectTopics(index, effective, ids)
    local TopicTree = ESOExporter.TopicTree
    if not ids or #ids == 0 then
        return TopicTree.Topics(index, effective)
    end
    local wanted = {}
    for _, id in ipairs(ids) do
        local under = TopicTree.TopicsUnder(index, id)
        if not under then
            return nil, "ESOExporter: '" .. id .. "' is not a topic or group."
        end
        for _, topicId in ipairs(under) do
            wanted[topicId] = true
        end
    end
    local selected = {}
    for _, topicId in ipairs(index.topics) do
        if wanted[topicId] then
            selected[#selected + 1] = topicId
        end
    end
    return selected
end

local function plural(count, one, many)
    return count .. " " .. (count == 1 and one or many)
end

--- The one line printed when a save that runs across frames starts.
function Commands.StartLine(count)
    return "ESOExporter: saving " .. plural(count, "topic", "topics") .. " in the background..."
end

--- Chat lines reporting a run: a summary, then one line per failed topic.
function Commands.Summary(result)
    local parts = { "ESOExporter: saved " .. plural(#result.stored, "topic", "topics") }
    if #result.missing > 0 then
        parts[#parts + 1] = plural(#result.missing, "topic has", "topics have") .. " no extractor yet"
    end
    if #result.failed > 0 then
        parts[#parts + 1] = plural(#result.failed, "topic", "topics") .. " failed"
    end
    if result.dropped > 0 then
        parts[#parts + 1] = plural(result.dropped, "value", "values") .. " dropped"
    end
    local lines = {
        table.concat(parts, "; ")
            .. ". The file is written on /reloadui, logout or quit (SavedVariables/ESOExporterData.lua).",
    }
    for _, failure in ipairs(result.failed) do
        lines[#lines + 1] = "ESOExporter: " .. failure.id .. " failed: " .. failure.message
    end
    return lines
end

ESOExporter = ESOExporter or {}
ESOExporter.Commands = Commands
return Commands
