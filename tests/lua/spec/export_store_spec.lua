-- LibExportStore: splitting, sanitizing, restoring, and entry storage.

local Lib = ESO.Load("src/LibExportStore/LibExportStore.lua")

-- Is every byte sequence in `s` made of whole UTF-8 characters? (Valid input only.)
local function startsOnCharacter(s)
    local b = s:byte(1)
    return b == nil or b < 0x80 or b >= 0xC0
end

-- A deterministic text of mixed 1, 2, 3 and 4 byte characters with line breaks.
local function mixedText(length, seed)
    math.randomseed(seed)
    local pieces = { "a", "Z", " ", "\n", "\195\169", "\226\130\172", "\240\159\152\128" }
    local out = {}
    for i = 1, length do
        out[i] = pieces[math.random(#pieces)]
    end
    return table.concat(out)
end

-- What the game does to a saved string it cannot hold: it drops it. Returns the first string
-- of 2000 characters or more found in `value`, or nil.
local function findTooLong(value)
    if type(value) == "string" then
        return #value >= 2000 and value or nil
    elseif type(value) == "table" then
        for k, v in pairs(value) do
            local found = findTooLong(k) or findTooLong(v)
            if found then
                return found
            end
        end
    end
    return nil
end

describe("SplitText", function()
    it("returns no parts for the empty string", function()
        eq(Lib.SplitText(""), {})
    end)

    it("returns one part for short text", function()
        eq(Lib.SplitText("hello"), { "hello" })
    end)

    it("joins back to exactly the original text", function()
        local samples = {
            "one line",
            "line one\nline two\n",
            "no trailing newline\nlast",
            "\n\n\nblank\n\nlines\n",
            string.rep("x", 5000),
            string.rep("word ", 600) .. "\n" .. string.rep("y", 4000) .. "\nend",
            mixedText(3000, 1),
        }
        for _, text in ipairs(samples) do
            for _, maxLen in ipairs({ 4, 7, 50, 1900 }) do
                eq(Lib.JoinText(Lib.SplitText(text, maxLen)), text)
            end
        end
    end)

    it("keeps every part within the limit", function()
        local text = mixedText(5000, 2)
        for _, maxLen in ipairs({ 4, 5, 9, 100 }) do
            for _, part in ipairs(Lib.SplitText(text, maxLen)) do
                truthy(#part <= maxLen, "part of " .. #part .. " bytes exceeds " .. maxLen)
            end
        end
    end)

    it("prefers to break at line ends", function()
        eq(Lib.SplitText("aaaa\nbbbb\ncccc\n", 10), { "aaaa\nbbbb\n", "cccc\n" })
    end)

    it("never cuts inside a UTF-8 character", function()
        local text = string.rep("\195\169\226\130\172\240\159\152\128", 40) -- 2, 3 and 4 byte characters
        for _, maxLen in ipairs({ 4, 5, 6, 7, 11 }) do
            for _, part in ipairs(Lib.SplitText(text, maxLen)) do
                truthy(startsOnCharacter(part), "a part starts in the middle of a character")
            end
        end
    end)

    it("uses the default limit of 1900 bytes", function()
        local parts = Lib.SplitText(string.rep("x", 5000))
        eq(#parts, 3)
        for _, part in ipairs(parts) do
            truthy(#part <= Lib.MAX_STRING)
        end
    end)

    it("rejects a limit smaller than one character", function()
        raises(function()
            Lib.SplitText("text", 3)
        end, "at least 4")
    end)

    it("rejects text that is not a string", function()
        raises(function()
            Lib.SplitText(42)
        end, "must be a string")
    end)
end)

describe("JoinText", function()
    it("rejects parts that are not strings", function()
        raises(function()
            Lib.JoinText({ "a", 2 })
        end, "part 2")
    end)
end)

describe("Sanitize", function()
    it("copies plain data without sharing tables", function()
        local input = { name = "x", n = 3, flag = true, list = { 1, 2, 3 }, nested = { a = { b = "c" } } }
        local clean, report = Lib.Sanitize(input)
        eq(clean, input)
        truthy(clean ~= input)
        truthy(clean.nested ~= input.nested)
        eq(report.dropped, 0)
        eq(report.truncated, false)
    end)

    it("does not modify its input", function()
        local input = { text = string.rep("x", 5000), fn = print }
        Lib.Sanitize(input)
        eq(input.text, string.rep("x", 5000))
        eq(input.fn, print)
    end)

    it("counts what it stored", function()
        local _, report = Lib.Sanitize({ a = "xy", b = 1, c = true, d = { e = "z" } })
        eq(report.tables, 2)
        eq(report.strings, 2)
        eq(report.numbers, 1)
        eq(report.booleans, 1)
        eq(report.nodes, 6)
        -- values "xy" and "z" plus the string keys a, b, c, d, e
        eq(report.stringBytes, 3 + 5)
    end)

    it("splits a long string into parts and Restore joins it again", function()
        local text = mixedText(4000, 3)
        local clean, report = Lib.Sanitize({ text = text })
        eq(report.longStrings, 1)
        truthy(type(clean.text) == "table")
        truthy(clean.text[Lib.PARTS_KEY])
        eq(Lib.Restore(clean), { text = text })
    end)

    it("keeps a string exactly at the limit and splits one byte over", function()
        local clean = Lib.Sanitize({ ok = string.rep("x", 10), long = string.rep("x", 11) }, { maxString = 10 })
        eq(clean.ok, string.rep("x", 10))
        eq(type(clean.long), "table")
    end)

    it("drops functions, threads and userdata and says where", function()
        local clean, report =
            Lib.Sanitize({ keep = 1, a = { fn = print, co = coroutine.create(function() end), file = io.stdout } })
        eq(clean, { keep = 1, a = {} })
        eq(report.dropped, 3)
        local joined = table.concat(report.droppedList, "|")
        truthy(joined:find("a.fn (function)", 1, true))
        truthy(joined:find("a.co (thread)", 1, true))
        truthy(joined:find("a.file (userdata)", 1, true))
    end)

    it("drops NaN and infinite numbers", function()
        local clean, report = Lib.Sanitize({ nan = 0 / 0, inf = math.huge, ninf = -math.huge, ok = 1.5 })
        eq(clean, { ok = 1.5 })
        eq(report.dropped, 3)
    end)

    it("drops a cycle and keeps the rest", function()
        local input = { keep = 1 }
        input.self = input
        local clean, report = Lib.Sanitize(input)
        eq(clean, { keep = 1 })
        eq(report.dropped, 1)
        truthy(report.droppedList[1]:find("cycle", 1, true))
    end)

    it("copies a table that appears twice without calling it a cycle", function()
        local shared = { v = 1 }
        local clean, report = Lib.Sanitize({ a = shared, b = shared })
        eq(clean, { a = { v = 1 }, b = { v = 1 } })
        eq(report.dropped, 0)
    end)

    it("drops tables nested deeper than the limit", function()
        local clean, report = Lib.Sanitize({ a = { b = { c = 1 } } }, { maxDepth = 2 })
        eq(clean, { a = {} })
        eq(report.dropped, 1)
    end)

    it("keeps number keys, including holes, and drops unsupported keys", function()
        local input = { [1] = "a", [3] = "c", [2.5] = "x", [true] = "no", [{}] = "no" }
        local clean, report = Lib.Sanitize(input)
        eq(clean, { [1] = "a", [3] = "c", [2.5] = "x" })
        eq(report.dropped, 2)
    end)

    it("drops the reserved key and keys that are too long", function()
        local clean, report = Lib.Sanitize({ [Lib.PARTS_KEY] = { "x" }, ok = 1, [string.rep("k", 20)] = 2 }, {
            maxString = 10,
        })
        eq(clean, { ok = 1 })
        eq(report.dropped, 2)
    end)

    it("stops at the node limit and says so", function()
        local input = {}
        for i = 1, 100 do
            input[i] = i
        end
        local clean, report = Lib.Sanitize(input, { maxNodes = 10 })
        eq(report.truncated, true)
        local count = 0
        for _ in pairs(clean) do
            count = count + 1
        end
        truthy(count < 100)
    end)

    it("returns nil and a report when the value itself cannot be stored", function()
        local clean, report = Lib.Sanitize(print)
        eq(clean, nil)
        eq(report.dropped, 1)
        eq(report.droppedList[1], "<root> (function)")
    end)

    it("leaves no stored string of 2000 characters or more", function()
        local input = {
            description = mixedText(9000, 4),
            lines = { mixedText(3000, 5), mixedText(2500, 6) },
            deep = { deeper = { text = mixedText(4100, 7) } },
        }
        local clean = Lib.Sanitize(input)
        eq(findTooLong(clean), nil)
        eq(Lib.Restore(clean), input)
    end)
end)

describe("Restore", function()
    it("joins parts and leaves other tables alone", function()
        local value = { a = { [Lib.PARTS_KEY] = { "he", "llo" } }, b = { [Lib.PARTS_KEY] = { "x" }, other = 1 } }
        eq(Lib.Restore(value), { a = "hello", b = { [Lib.PARTS_KEY] = { "x" }, other = 1 } })
    end)

    it("does not modify its input", function()
        local value = { a = { [Lib.PARTS_KEY] = { "he", "llo" } } }
        Lib.Restore(value)
        eq(value, { a = { [Lib.PARTS_KEY] = { "he", "llo" } } })
    end)

    it("leaves parts that are not all strings as they are", function()
        local value = { [Lib.PARTS_KEY] = { "a", 2 } }
        eq(Lib.Restore(value), value)
    end)

    it("raises on a cycle instead of looping", function()
        local value = {}
        value.self = value
        raises(function()
            Lib.Restore(value)
        end, "cycle")
    end)
end)

describe("NewEntry", function()
    it("wraps sanitized data with a kind, timestamp and report", function()
        local entry = Lib.NewEntry({ a = 1, f = print }, { timestamp = 1700000000 })
        eq(entry.kind, "data")
        eq(entry.timestamp, 1700000000)
        eq(entry.data, { a = 1 })
        eq(entry.report.dropped, 1)
    end)
end)

describe("Put and Remove", function()
    it("creates the container and the path", function()
        local container = Lib.Put(nil, { "characters", "1", "topics", "stats" }, { kind = "data" })
        eq(container, { characters = { ["1"] = { topics = { stats = { kind = "data" } } } } })
    end)

    it("replaces an entry at the same path and keeps its siblings", function()
        local container = Lib.Put(nil, { "a", "x" }, { v = 1 })
        Lib.Put(container, { "a", "y" }, { v = 2 })
        Lib.Put(container, { "a", "x" }, { v = 3 })
        eq(container, { a = { x = { v = 3 }, y = { v = 2 } } })
    end)

    it("replaces a non-table value that is in the way", function()
        local container = { a = "stale" }
        Lib.Put(container, { "a", "x" }, { v = 1 })
        eq(container, { a = { x = { v = 1 } } })
    end)

    it("accepts number keys in the path", function()
        eq(Lib.Put(nil, { "characters", 42, "name" }, "n"), { characters = { [42] = { name = "n" } } })
    end)

    it("rejects an empty or invalid path", function()
        raises(function()
            Lib.Put({}, {}, {})
        end, "non-empty")
        raises(function()
            Lib.Put({}, { "a", true }, {})
        end, "must be a string or number")
        raises(function()
            Lib.Remove({}, "a")
        end, "non-empty")
    end)

    it("removes an entry and reports whether it did", function()
        local container = Lib.Put(nil, { "a", "x" }, { v = 1 })
        eq(Lib.Remove(container, { "a", "x" }), true)
        eq(container, { a = {} })
        eq(Lib.Remove(container, { "a", "x" }), false)
        eq(Lib.Remove(container, { "missing", "x" }), false)
        eq(Lib.Remove(nil, { "a" }), false)
    end)
end)

describe("Summarize", function()
    it("is empty for a missing or empty container", function()
        eq(Lib.Summarize(nil).entries, 0)
        eq(Lib.Summarize({}).entries, 0)
    end)

    it("adds up entries, ages and sizes", function()
        local container = { meta = { schema = 1, kind = "data" } }
        Lib.Put(container, { "account", "topics", "currency" }, Lib.NewEntry({ gold = 5 }, { timestamp = 100 }))
        Lib.Put(
            container,
            { "characters", "1", "topics", "stats" },
            Lib.NewEntry({ health = 9, fn = print }, { timestamp = 300 })
        )
        Lib.Put(container, { "characters", "1", "topics", "cp" }, Lib.NewEntry({ points = 1 }, { timestamp = 200 }))
        local summary = Lib.Summarize(container)
        eq(summary.entries, 3)
        eq(summary.oldest, 100)
        eq(summary.newest, 300)
        eq(summary.dropped, 1)
        truthy(summary.nodes > 0)
        truthy(summary.stringBytes > 0)
    end)

    it("does not look inside an entry's data", function()
        local container = Lib.Put(nil, { "a" }, Lib.NewEntry({ inner = { kind = "data" } }))
        eq(Lib.Summarize(container).entries, 1)
    end)
end)
