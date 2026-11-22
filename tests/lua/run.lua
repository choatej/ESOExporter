-- Test runner: luajit tests/lua/run.lua [spec-name-filter]
--
-- Runs every tests/lua/spec/*_spec.lua. The global table is restored after each spec so
-- globals created by the code under test (and ESO stubs) cannot leak between specs.
-- Exits non-zero on any failure.

local scriptPath = (arg and arg[0]) or "tests/lua/run.lua"
local testsDir = scriptPath:match("^(.*)/run%.lua$") or "."
local root = testsDir .. "/../.."

package.path = testsDir .. "/?.lua;" .. package.path
local Framework = require("framework")
local Stubs = require("eso_stubs")
Stubs.root = root

local filter = arg and arg[1]

-- List spec files with the shell (plain Lua has no directory listing).
local specs = {}
local pipe = assert(io.popen('ls "' .. testsDir .. '/spec" 2>/dev/null'))
for name in pipe:lines() do
    if name:match("_spec%.lua$") and (not filter or name:find(filter, 1, true)) then
        specs[#specs + 1] = name
    end
end
pipe:close()
table.sort(specs)

if #specs == 0 then
    io.stderr:write("no specs found" .. (filter and (" matching '" .. filter .. "'") or "") .. "\n")
    os.exit(1)
end

-- Snapshot the globals so each spec starts from the same environment.
local pristine = {}
for k, v in pairs(_G) do
    pristine[k] = v
end
local function restoreGlobals()
    for k in pairs(_G) do
        if pristine[k] == nil then
            _G[k] = nil
        end
    end
    for k, v in pairs(pristine) do
        _G[k] = v
    end
end

local totalPassed, totalFailed = 0, 0
for _, name in ipairs(specs) do
    local suite = Framework.NewSuite(name)
    _G.describe = suite.describe
    _G.it = suite.it
    _G.before_each = suite.before_each
    for assertName, fn in pairs(suite.assertions) do
        _G[assertName] = fn
    end
    _G.ESO = Stubs

    local chunk, loadErr = loadfile(testsDir .. "/spec/" .. name)
    if not chunk then
        suite.failures[#suite.failures + 1] = { name = "(load)", message = tostring(loadErr) }
    else
        local ok, err = xpcall(chunk, debug.traceback)
        if not ok then
            suite.failures[#suite.failures + 1] = { name = "(spec body)", message = tostring(err) }
        end
    end

    totalPassed = totalPassed + suite.passed
    totalFailed = totalFailed + #suite.failures
    print(string.format("%-34s %3d passed, %d failed", name, suite.passed, #suite.failures))
    for _, failure in ipairs(suite.failures) do
        print("  FAIL " .. failure.name)
        for line in tostring(failure.message):gmatch("[^\n]+") do
            print("       " .. line)
        end
    end

    restoreGlobals()
end

print(string.format("\n%d passed, %d failed", totalPassed, totalFailed))
os.exit(totalFailed == 0 and 0 or 1)
