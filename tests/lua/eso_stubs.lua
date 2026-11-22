-- Helpers for loading project source into a test, and stand-ins for the parts of the ESO
-- environment that code touches at load time. Add a stub here when a module needs one, and
-- keep each stub as small as the module's use of it. Pure code (such as the export library)
-- needs none.

local Stubs = {}

-- Directory of the repository root, set by the runner.
Stubs.root = "."

-- Load one source file (path relative to the repository root) into the current globals and
-- return whatever the chunk returns.
function Stubs.Load(relativePath)
    local chunk, err = loadfile(Stubs.root .. "/" .. relativePath)
    if not chunk then
        error("cannot load " .. relativePath .. ": " .. tostring(err), 2)
    end
    return chunk()
end

return Stubs
