-- LibExportStore
-- Helpers for storing structured data in SavedVariables so an outside tool can read it.
--
-- ESO add-ons cannot write files. The game writes an add-on's SavedVariables globals to
-- SavedVariables/<AddOn>.lua on /reloadui, logout or quit. Two things make that awkward:
--   * Any single string of 2000 characters or more is silently dropped when saved.
--   * Functions, userdata, NaN and cycles cannot be saved at all.
--
-- This library is pure functions over tables. It has no dependencies, declares no
-- SavedVariables of its own, and makes no game calls: the caller owns the container table
-- (its own SavedVariables global) and passes it in. Plain Lua 5.1.
--
--   local entry = LibExportStore.NewEntry(extractedTable, { timestamp = GetTimeStamp() })
--   MyAddonData = LibExportStore.Put(MyAddonData, { "characters", id, "topics", "equipment" }, entry)
--
-- A stored entry is { kind = "data", timestamp = number|nil, data = table, report = table }.
-- A string that was too long is stored as { ["$parts"] = { "...", "..." } }; join the parts
-- with no separator (Restore does this for you).

local Lib = {}

Lib.VERSION = "0.1.0"

-- SavedVariables drop any single string of 2000+ characters; stay well below.
Lib.MAX_STRING = 1900
Lib.MAX_DEPTH = 16
Lib.MAX_NODES = 200000
Lib.MAX_DROPPED_LISTED = 50
Lib.PARTS_KEY = "$parts"

-- A UTF-8 character is at most 4 bytes, so a piece can never be smaller than that.
local MIN_PIECE = 4

local table_concat = table.concat

-- =====================================================
-- TEXT SPLITTING
-- =====================================================

--- Number of bytes in the UTF-8 character that starts at byte `pos`.
-- Lua 5.1 strings are bytes, so the lead byte is read directly. Continuation bytes and
-- invalid lead bytes count as one so a malformed string still makes progress.
local function Utf8CharLen(s, pos)
    local b = s:byte(pos)
    if not b or b < 0xC0 then
        return 1
    elseif b < 0xE0 then
        return 2
    elseif b < 0xF0 then
        return 3
    elseif b < 0xF8 then
        return 4
    end
    return 1
end

--- Cut `text` into pieces of at most `maxLen` bytes, preferring line boundaries.
-- A piece ends where a line ends ("\n") unless one line is longer than `maxLen`; that line
-- is cut between UTF-8 characters, never inside one. Joining the pieces with no separator
-- returns the original text exactly.
-- @param text string
-- @param maxLen number|nil defaults to Lib.MAX_STRING; must be at least 4
-- @return table array of strings (empty for the empty string)
function Lib.SplitText(text, maxLen)
    if type(text) ~= "string" then
        error("SplitText: text must be a string, got " .. type(text), 2)
    end
    maxLen = maxLen or Lib.MAX_STRING
    if type(maxLen) ~= "number" or maxLen < MIN_PIECE then
        error("SplitText: maxLen must be a number of at least " .. MIN_PIECE, 2)
    end

    local parts = {}
    local buffer = {}
    local bufferLen = 0

    local function flush()
        if bufferLen > 0 then
            parts[#parts + 1] = table_concat(buffer)
            buffer = {}
            bufferLen = 0
        end
    end

    local function add(piece)
        if bufferLen + #piece > maxLen then
            flush()
        end
        buffer[#buffer + 1] = piece
        bufferLen = bufferLen + #piece
    end

    -- Lines keep their trailing newline; the final line may not have one.
    for line in text:gmatch("[^\n]*\n?") do
        if line ~= "" then
            if #line <= maxLen then
                add(line)
            else
                flush()
                local pos = 1
                while pos <= #line do
                    local stop = pos
                    while stop <= #line do
                        local nextStop = stop + Utf8CharLen(line, stop)
                        if nextStop - pos > maxLen then
                            break
                        end
                        stop = nextStop
                    end
                    parts[#parts + 1] = line:sub(pos, stop - 1)
                    pos = stop
                end
            end
        end
    end
    flush()
    return parts
end

--- Join the pieces from SplitText back into the original text.
-- @param parts table array of strings
-- @return string
function Lib.JoinText(parts)
    if type(parts) ~= "table" then
        error("JoinText: parts must be a table, got " .. type(parts), 2)
    end
    for i, piece in ipairs(parts) do
        if type(piece) ~= "string" then
            error("JoinText: part " .. i .. " is a " .. type(piece) .. ", not a string", 2)
        end
    end
    return table_concat(parts)
end

-- =====================================================
-- SANITIZING
-- =====================================================

local function PathString(path, depth)
    if depth == 0 then
        return "<root>"
    end
    local pieces = {}
    for i = 1, depth do
        pieces[i] = tostring(path[i])
    end
    return table_concat(pieces, ".")
end

--- Copy `value` into a form SavedVariables can store, and report what changed.
--   * a string longer than the limit becomes { ["$parts"] = { "...", "..." } }
--   * functions, userdata, threads, NaN and infinite numbers are dropped
--   * keys that are not strings or finite numbers are dropped, as are string keys longer
--     than the limit and the reserved key "$parts"
--   * cycles and tables nested deeper than the limit are dropped
-- The input is never modified. Numeric keys are kept as they are, so a table with holes
-- stays a table with those keys. A table shared in two places is copied twice.
-- @param value any usually a table
-- @param options table|nil { maxString, maxDepth, maxNodes }
-- @return any the sanitized copy (nil if the value itself had to be dropped)
-- @return table report { tables, strings, longStrings, numbers, booleans, nodes, stringBytes,
--         dropped, droppedList, truncated }
function Lib.Sanitize(value, options)
    options = options or {}
    local maxString = options.maxString or Lib.MAX_STRING
    local maxDepth = options.maxDepth or Lib.MAX_DEPTH
    local maxNodes = options.maxNodes or Lib.MAX_NODES

    local report = {
        tables = 0,
        strings = 0,
        longStrings = 0,
        numbers = 0,
        booleans = 0,
        nodes = 0,
        stringBytes = 0,
        dropped = 0,
        droppedList = {},
        truncated = false,
    }
    local nodes = 0
    local ancestors = {} -- tables currently being copied; seeing one again means a cycle
    local path, depth = {}, 0

    local function drop(reason)
        report.dropped = report.dropped + 1
        if #report.droppedList < Lib.MAX_DROPPED_LISTED then
            report.droppedList[#report.droppedList + 1] = PathString(path, depth) .. " (" .. reason .. ")"
        end
    end

    local function keyProblem(key)
        local keyType = type(key)
        if keyType == "string" then
            if key == Lib.PARTS_KEY then
                return "reserved key"
            end
            if #key > maxString then
                return "key longer than " .. maxString
            end
            return nil
        elseif keyType == "number" then
            if key ~= key or key == math.huge or key == -math.huge then
                return "key is NaN or infinite"
            end
            return nil
        end
        return "key of type " .. keyType
    end

    local copy
    copy = function(v)
        nodes = nodes + 1
        if nodes > maxNodes then
            report.truncated = true
            return nil
        end

        local kind = type(v)
        if kind == "boolean" then
            report.booleans = report.booleans + 1
            report.nodes = report.nodes + 1
            return v
        elseif kind == "number" then
            if v ~= v or v == math.huge or v == -math.huge then
                drop("number is NaN or infinite")
                return nil
            end
            report.numbers = report.numbers + 1
            report.nodes = report.nodes + 1
            return v
        elseif kind == "string" then
            report.stringBytes = report.stringBytes + #v
            report.nodes = report.nodes + 1
            if #v > maxString then
                report.longStrings = report.longStrings + 1
                return { [Lib.PARTS_KEY] = Lib.SplitText(v, maxString) }
            end
            report.strings = report.strings + 1
            return v
        elseif kind == "table" then
            if depth >= maxDepth then
                drop("nested deeper than " .. maxDepth)
                return nil
            end
            if ancestors[v] then
                drop("cycle")
                return nil
            end
            ancestors[v] = true
            local out = {}
            for key, item in pairs(v) do
                depth = depth + 1
                path[depth] = key
                local problem = keyProblem(key)
                if problem then
                    drop(problem)
                else
                    if type(key) == "string" then
                        report.stringBytes = report.stringBytes + #key
                    end
                    local copied = copy(item)
                    if copied ~= nil then
                        out[key] = copied
                    end
                end
                depth = depth - 1
            end
            ancestors[v] = nil
            report.tables = report.tables + 1
            report.nodes = report.nodes + 1
            return out
        end

        -- function, userdata, thread
        drop(kind)
        return nil
    end

    local clean = copy(value)
    return clean, report
end

--- Undo the long-string splitting done by Sanitize.
-- A table whose only key is "$parts" and whose value is an array of strings becomes the
-- joined string; everything else is copied unchanged. The input is never modified.
-- @param value any
-- @return any
function Lib.Restore(value)
    local ancestors = {}
    local restore
    restore = function(v)
        if type(v) ~= "table" then
            return v
        end
        if ancestors[v] then
            error("Restore: the value contains a cycle", 3)
        end
        local parts = v[Lib.PARTS_KEY]
        if type(parts) == "table" and next(v, Lib.PARTS_KEY) == nil and next(v) == Lib.PARTS_KEY then
            local joinable = true
            for _, piece in ipairs(parts) do
                if type(piece) ~= "string" then
                    joinable = false
                end
            end
            if joinable then
                return table_concat(parts)
            end
        end
        ancestors[v] = true
        local out = {}
        for key, item in pairs(v) do
            out[key] = restore(item)
        end
        ancestors[v] = nil
        return out
    end
    return restore(value)
end

-- =====================================================
-- ENTRIES AND CONTAINERS
-- =====================================================

--- Build a storable entry from extracted data.
-- @param value table|any the data to store (sanitized here)
-- @param options table|nil { timestamp = number, maxString, maxDepth, maxNodes }
-- @return table { kind = "data", timestamp, data, report }
function Lib.NewEntry(value, options)
    options = options or {}
    local clean, report = Lib.Sanitize(value, options)
    return {
        kind = "data",
        timestamp = options.timestamp,
        data = clean,
        report = report,
    }
end

local function CheckPath(path, name)
    if type(path) ~= "table" or #path == 0 then
        error(name .. ": path must be a non-empty array of keys", 3)
    end
    for i, key in ipairs(path) do
        local keyType = type(key)
        if keyType ~= "string" and keyType ~= "number" then
            error(name .. ": path key " .. i .. " must be a string or number, got " .. keyType, 3)
        end
    end
end

--- Store `entry` at `path` inside `container` and return the container.
-- Missing tables along the path are created, a non-table value in the way is replaced, and
-- an entry already at the path is replaced. Other entries are untouched.
-- @param container table|nil existing saved table (a new one is created if nil)
-- @param path table array of keys, e.g. { "characters", id, "topics", "equipment" }
-- @param entry table usually from NewEntry
-- @return table container
function Lib.Put(container, path, entry)
    CheckPath(path, "Put")
    if type(container) ~= "table" then
        container = {}
    end
    local node = container
    for i = 1, #path - 1 do
        local key = path[i]
        if type(node[key]) ~= "table" then
            node[key] = {}
        end
        node = node[key]
    end
    node[path[#path]] = entry
    return container
end

--- Remove the entry at `path`. Parent tables are left in place.
-- @param container table|nil
-- @param path table array of keys
-- @return boolean true if something was removed
function Lib.Remove(container, path)
    CheckPath(path, "Remove")
    if type(container) ~= "table" then
        return false
    end
    local node = container
    for i = 1, #path - 1 do
        node = node[path[i]]
        if type(node) ~= "table" then
            return false
        end
    end
    local last = path[#path]
    if node[last] == nil then
        return false
    end
    node[last] = nil
    return true
end

local SUMMARY_MAX_DEPTH = 8

--- Summarize the entries stored in `container`, for example for a login reminder.
-- Entries are found by their `kind = "data"` marker together with a `report` table (which
-- NewEntry always adds); the search does not descend into one.
-- @param container table|nil
-- @return table { entries, oldest, newest, nodes, stringBytes, dropped } where oldest and
--         newest are timestamps (nil when none are recorded)
function Lib.Summarize(container)
    local summary = { entries = 0, oldest = nil, newest = nil, nodes = 0, stringBytes = 0, dropped = 0 }
    if type(container) ~= "table" then
        return summary
    end

    local function visit(node, depth)
        if type(node) ~= "table" or depth > SUMMARY_MAX_DEPTH then
            return
        end
        if node.kind == "data" and type(node.report) == "table" then
            summary.entries = summary.entries + 1
            local ts = node.timestamp
            if type(ts) == "number" then
                if not summary.oldest or ts < summary.oldest then
                    summary.oldest = ts
                end
                if not summary.newest or ts > summary.newest then
                    summary.newest = ts
                end
            end
            local report = node.report
            if type(report) == "table" then
                summary.nodes = summary.nodes + (tonumber(report.nodes) or 0)
                summary.stringBytes = summary.stringBytes + (tonumber(report.stringBytes) or 0)
                summary.dropped = summary.dropped + (tonumber(report.dropped) or 0)
            end
            return
        end
        for _, child in pairs(node) do
            visit(child, depth + 1)
        end
    end

    visit(container, 0)
    return summary
end

-- ESO loads files as chunks; the global lets other add-ons use the library once it is
-- listed in their manifest's DependsOn. Returning it also lets offline tests load the file.
LibExportStore = Lib
return Lib
