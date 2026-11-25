-- ESOExporter.Runner: runs extractors under pcall and stores entries where schema v1 puts them.

local Store = ESO.Load("src/LibExportStore/LibExportStore.lua")
ESO.Load("src/ESOExporter/TopicTree.lua")
ESO.Load("src/ESOExporter/Registry.lua")
local Runner = ESO.Load("src/ESOExporter/Runner.lua")
local TopicTree, Registry = ESOExporter.TopicTree, ESOExporter.Registry

local function topic(id, scope)
    return { id = id, type = "topic", label = id, default = true, scope = scope, cost = "light" }
end

local function newIndex()
    return TopicTree.Index({
        version = 1,
        nodes = {
            {
                id = "account",
                type = "group",
                label = "a",
                default = true,
                children = { topic("account.currency", "account") },
            },
            {
                id = "character",
                type = "group",
                label = "c",
                default = true,
                children = { topic("character.identity", "character"), topic("character.title", "character") },
            },
        },
    })
end

local META = { schema = 1, addon = "ESOExporter", addonVersion = "0.1.0", apiVersion = 101051 }
local CHARACTER = { id = "4500000000000001", name = "Test Character One" }

local function job(index, registry, ids, container)
    return {
        index = index,
        registry = registry,
        ids = ids,
        container = container,
        meta = META,
        character = CHARACTER,
        timestamp = 1795000000,
    }
end

describe("Runner.Run", function()
    it("stores account and character entries at their schema paths", function()
        local index = newIndex()
        local registry = Registry.New(index)
        registry:Register("account.currency", function()
            return { gold = 12 }
        end)
        registry:Register("character.identity", function(id)
            return { level = 50, topic = id }
        end)

        local container, result = Runner.Run(job(index, registry, { "account.currency", "character.identity" }))

        eq(container.meta, META)
        local currency = container.account.topics["account.currency"]
        eq(currency.kind, "data")
        eq(currency.timestamp, 1795000000)
        eq(currency.data, { gold = 12 })
        local character = container.characters["4500000000000001"]
        eq(character.name, "Test Character One")
        eq(character.topics["character.identity"].data, { level = 50, topic = "character.identity" })
        eq(result.stored, { "account.currency", "character.identity" })
        eq(result.missing, {})
        eq(result.failed, {})
        eq(result.nodes, currency.report.nodes + character.topics["character.identity"].report.nodes)
    end)

    it("writes only meta when nothing has an extractor, and lists the missing topics", function()
        local index = newIndex()
        local container, result = Runner.Run(job(index, Registry.New(index), { "account.currency" }))
        eq(container, { meta = META })
        eq(result.missing, { "account.currency" })
        eq(result.stored, {})
    end)

    it("isolates an extractor that raises, and keeps running the others", function()
        local index = newIndex()
        local registry = Registry.New(index)
        registry:Register("character.identity", function()
            error("boom")
        end)
        registry:Register("character.title", function()
            return { titleId = 3 }
        end)

        local container, result = Runner.Run(job(index, registry, { "character.identity", "character.title" }))

        eq(#result.failed, 1)
        eq(result.failed[1].id, "character.identity")
        truthy(result.failed[1].message:find("boom", 1, true), "the error message is kept")
        eq(result.stored, { "character.title" })
        eq(container.characters["4500000000000001"].topics["character.identity"], nil)
    end)

    it("rejects an extractor that returns something other than a table", function()
        local index = newIndex()
        local registry = Registry.New(index)
        registry:Register("character.identity", function()
            return "text"
        end)
        local container, result = Runner.Run(job(index, registry, { "character.identity" }))
        eq(result.failed[1].message, "the extractor returned a string, not a table")
        eq(container.characters, nil)
    end)

    it("fails a character topic when there is no character", function()
        local index = newIndex()
        local registry = Registry.New(index)
        registry:Register("character.identity", function()
            return {}
        end)
        local j = job(index, registry, { "character.identity" })
        j.character = nil
        local _, result = Runner.Run(j)
        eq(result.failed[1].message, "no character to store it under")
    end)

    it("fails an id that is not a topic", function()
        local index = newIndex()
        local _, result = Runner.Run(job(index, Registry.New(index), { "character", "nope" }))
        eq(#result.failed, 2)
        eq(result.failed[1].message, "not a topic in the tree")
    end)

    it("replaces a topic's entry and keeps entries of topics that did not run", function()
        local index = newIndex()
        local registry = Registry.New(index)
        local level = 10
        registry:Register("character.identity", function()
            return { level = level }
        end)
        registry:Register("character.title", function()
            return { titleId = 3 }
        end)

        local container = Runner.Run(job(index, registry, { "character.identity", "character.title" }))
        level = 11
        container = Runner.Run(job(index, registry, { "character.identity" }, container))

        local topics = container.characters["4500000000000001"].topics
        eq(topics["character.identity"].data, { level = 11 })
        eq(topics["character.title"].data, { titleId = 3 })
    end)

    it("sanitizes what it stores", function()
        local index = newIndex()
        local registry = Registry.New(index)
        registry:Register("account.currency", function()
            return { long = string.rep("x", 2500), fn = print }
        end)
        local container, result = Runner.Run(job(index, registry, { "account.currency" }))
        local data = container.account.topics["account.currency"].data
        eq(#data.long[Store.PARTS_KEY], 2)
        eq(data.fn, nil)
        eq(result.dropped, 1)
    end)

    it("raises for a malformed job", function()
        raises(function()
            Runner.Run({})
        end, "needs index, registry and ids")
        local index = newIndex()
        raises(function()
            Runner.Run({ index = index, registry = Registry.New(index), ids = {} })
        end, "needs meta")
    end)
end)

describe("Runner.RunAsync", function()
    local function setup()
        local index = newIndex()
        local registry = Registry.New(index)
        registry:Register("account.currency", function()
            return { gold = 12 }
        end)
        registry:Register("character.identity", function(id, task)
            return { level = 50, topic = id, hasTask = task ~= nil }
        end)
        return index, registry
    end

    -- A scheduler that queues steps until the test runs them, as a frame-budgeted task would.
    local function manual()
        local queue = {}
        return function(step)
            queue[#queue + 1] = step
        end, queue
    end

    it("does one topic per scheduled step and finishes with onDone", function()
        local index, registry = setup()
        local scheduler, queue = manual()
        local done
        Runner.RunAsync(
            job(index, registry, { "account.currency", "character.identity" }),
            scheduler,
            function(container, result)
                done = { container = container, result = result }
            end
        )
        eq(#queue, 1, "nothing runs until the scheduler does")
        eq(done, nil)

        table.remove(queue, 1)()
        eq(#queue, 1)
        eq(done, nil, "one topic done, one to go")

        table.remove(queue, 1)()
        table.remove(queue, 1)()
        truthy(done, "the step after the last topic reports")
        eq(done.result.stored, { "account.currency", "character.identity" })
        eq(done.container.account.topics["account.currency"].data, { gold = 12 })
    end)

    it("gives the same result as Run", function()
        local ids = { "account.currency", "character.identity", "character.title" }
        local index, registry = setup()
        local syncContainer, syncResult = Runner.Run(job(index, registry, ids))
        local asyncContainer, asyncResult
        Runner.RunAsync(job(index, registry, ids), function(step)
            step()
        end, function(container, result)
            asyncContainer, asyncResult = container, result
        end)
        eq(asyncContainer, syncContainer)
        eq(asyncResult, syncResult)
        eq(asyncResult.missing, { "character.title" })
    end)

    it("passes the job's task handle to extractors", function()
        local index, registry = setup()
        local j = job(index, registry, { "character.identity" })
        j.task = {}
        local container
        Runner.RunAsync(j, function(step)
            step()
        end, function(c)
            container = c
        end)
        eq(container.characters[CHARACTER.id].topics["character.identity"].data.hasTask, true)
    end)

    it("isolates a failing extractor and still finishes", function()
        local index, registry = setup()
        registry:Register("character.title", function()
            error("boom")
        end)
        local scheduler, queue = manual()
        local result
        Runner.RunAsync(job(index, registry, { "character.title", "character.identity" }), scheduler, function(_, r)
            result = r
        end)
        while #queue > 0 do
            table.remove(queue, 1)()
        end
        eq(result.stored, { "character.identity" })
        eq(#result.failed, 1)
        eq(result.failed[1].id, "character.title")
    end)

    it("raises for a malformed job or missing callbacks before scheduling anything", function()
        local index, registry = setup()
        local scheduled = 0
        local function scheduler()
            scheduled = scheduled + 1
        end
        local function noop() end
        falsy(pcall(Runner.RunAsync, { index = index }, scheduler, noop))
        falsy(pcall(Runner.RunAsync, job(index, registry, {}), nil, noop))
        falsy(pcall(Runner.RunAsync, job(index, registry, {}), scheduler, nil))
        eq(scheduled, 0)
    end)
end)
