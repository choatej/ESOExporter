-- Minimal offline test framework for the project's Lua code (LuaJIT / Lua 5.1, no dependencies).
--
-- A spec file calls describe(), it(), before_each() and the assertion helpers below; all are
-- provided as globals while the spec loads. The runner (tests/lua/run.lua) restores the global
-- table between spec files, so one spec cannot leak state into the next.

local Framework = {}

local function describeValue(v)
    if type(v) == "string" then
        return string.format("%q", v)
    end
    return tostring(v)
end

local function deepEqual(a, b, seen)
    if a == b then
        return true
    end
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end
    seen = seen or {}
    if seen[a] == b then
        return true
    end
    seen[a] = b
    for k, v in pairs(a) do
        if not deepEqual(v, b[k], seen) then
            return false
        end
    end
    for k in pairs(b) do
        if a[k] == nil then
            return false
        end
    end
    return true
end

-- Assertions. Each raises with a readable message (level 2 points at the caller).
local Assertions = {}

function Assertions.eq(actual, expected, message)
    if not deepEqual(actual, expected) then
        error(
            (message and (message .. ": ") or "")
                .. "expected "
                .. describeValue(expected)
                .. ", got "
                .. describeValue(actual),
            2
        )
    end
end

function Assertions.truthy(value, message)
    if not value then
        error(message or ("expected a truthy value, got " .. describeValue(value)), 2)
    end
end

function Assertions.falsy(value, message)
    if value then
        error(message or ("expected a falsy value, got " .. describeValue(value)), 2)
    end
end

-- raises(fn [, text]): fn must error; if text is given the message must contain it (plain find).
function Assertions.raises(fn, text)
    local ok, err = pcall(fn)
    if ok then
        error("expected an error, but the call succeeded", 2)
    end
    if text and not tostring(err):find(text, 1, true) then
        error("error message " .. describeValue(tostring(err)) .. " does not contain " .. describeValue(text), 2)
    end
end

-- Collects the results of one spec file.
function Framework.NewSuite(fileName)
    local suite = {
        file = fileName,
        passed = 0,
        failures = {},
        _stack = {},
        _beforeEach = {},
    }

    local function fullName(name)
        local parts = {}
        for _, p in ipairs(suite._stack) do
            parts[#parts + 1] = p
        end
        parts[#parts + 1] = name
        return table.concat(parts, " > ")
    end

    function suite.describe(name, body)
        suite._stack[#suite._stack + 1] = name
        local hooksBefore = #suite._beforeEach
        local ok, err = pcall(body)
        if not ok then
            suite.failures[#suite.failures + 1] = { name = fullName("(describe body)"), message = tostring(err) }
        end
        for i = #suite._beforeEach, hooksBefore + 1, -1 do
            suite._beforeEach[i] = nil
        end
        suite._stack[#suite._stack] = nil
    end

    function suite.before_each(fn)
        suite._beforeEach[#suite._beforeEach + 1] = fn
    end

    function suite.it(name, body)
        local ok, err = true, nil
        for _, hook in ipairs(suite._beforeEach) do
            ok, err = pcall(hook)
            if not ok then
                break
            end
        end
        if ok then
            ok, err = xpcall(body, function(e)
                return debug.traceback(tostring(e), 2)
            end)
        end
        if ok then
            suite.passed = suite.passed + 1
        else
            suite.failures[#suite.failures + 1] = { name = fullName(name), message = tostring(err) }
        end
    end

    suite.assertions = Assertions
    return suite
end

return Framework
