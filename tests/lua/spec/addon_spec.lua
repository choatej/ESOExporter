-- The add-ons as the game loads them: every manifest file in order, against stand-in game globals.
-- This covers the glue in ESOExporter.lua that the pure modules' specs do not.

local function readFile(path)
    local file = assert(io.open(ESO.root .. "/" .. path, "r"))
    local text = file:read("*a")
    file:close()
    return text
end

local function loadAll(values)
    local game = ESO.Game(values)
    ESO.LoadAddOn("src/LibExportStore")
    ESO.LoadAddOn("src/ESOExporterData")
    local manifest = ESO.LoadAddOn("src/ESOExporter")
    return game, manifest
end

describe("ESOExporter add-on", function()
    before_each(function()
        ESOExporter = nil
        ESOExporterData = nil
    end)

    it("loads from its manifest and registers the slash commands once loaded", function()
        local game = loadAll()
        eq(SLASH_COMMANDS["/esoexport"], nil, "nothing is registered before EVENT_ADD_ON_LOADED")
        game.fire(EVENT_ADD_ON_LOADED, "SomeOtherAddOn")
        eq(SLASH_COMMANDS["/esoexport"], nil, "another add-on's load is ignored")
        game.fire(EVENT_ADD_ON_LOADED, "ESOExporter")
        eq(SLASH_COMMANDS["/esoexport"], ESOExporter.HandleCommand)
        eq(SLASH_COMMANDS["/eox"], ESOExporter.HandleCommand)
    end)

    it("has the version its manifest declares", function()
        local _, manifest = loadAll()
        eq(manifest:match("## Version: (%S+)"), ESOExporter.VERSION)
    end)

    it("depends on the export library and the data add-on", function()
        local _, manifest = loadAll()
        local depends = manifest:match("## DependsOn: ([^\n]+)")
        truthy(depends and depends:find("LibExportStore", 1, true), "depends on LibExportStore")
        truthy(depends and depends:find("ESOExporterData", 1, true), "depends on ESOExporterData")
    end)

    it("names the export global as the data add-on's SavedVariables", function()
        truthy(
            readFile("src/ESOExporterData/ESOExporterData.txt"):find("## SavedVariables: ESOExporterData\n", 1, true)
        )
    end)

    it("saves meta from the game, and an extractor's entry under the current character", function()
        local game = loadAll({ characterId = "4500000000000007", characterName = "Test Character Seven" })
        ESOExporter.Register("character.stats.offense", function()
            return { level = 50 }
        end)
        game.fire(EVENT_ADD_ON_LOADED, "ESOExporter")

        SLASH_COMMANDS["/eox"]("save character.stats.offense")

        eq(ESOExporterData.meta, {
            schema = 1,
            addon = "ESOExporter",
            addonVersion = ESOExporter.VERSION,
            apiVersion = 101051,
            gameVersion = "eso.live.12.1.7.3318083",
            server = "NA Megaserver",
        })
        local character = ESOExporterData.characters["4500000000000007"]
        eq(character.name, "Test Character Seven")
        eq(character.topics["character.stats.offense"].data, { level = 50 })
        eq(character.topics["character.stats.offense"].timestamp, 1795000000)
        truthy(game.printed[1]:find("saved 1 topic", 1, true), game.printed[1])
    end)

    it("keeps what is already saved", function()
        local game = loadAll()
        game.fire(EVENT_ADD_ON_LOADED, "ESOExporter")
        ESOExporterData = { account = { topics = { ["account.currency"] = { kind = "data" } } } }
        SLASH_COMMANDS["/esoexport"]("save")
        eq(ESOExporterData.account.topics["account.currency"], { kind = "data" })
        eq(ESOExporterData.meta.schema, 1)
    end)

    it("saves the character's identity as raw ids and numbers", function()
        local game = loadAll({
            identity = { raceId = 3, classId = 6, gender = 1, alliance = 2, level = 50, championPoints = 1234 },
        })
        game.fire(EVENT_ADD_ON_LOADED, "ESOExporter")
        SLASH_COMMANDS["/eox"]("save character.identity")
        local entry = ESOExporterData.characters["4500000000000001"].topics["character.identity"]
        eq(entry.data, { raceId = 3, classId = 6, gender = 1, alliance = 2, level = 50, championPoints = 1234 })
        eq(entry.report.dropped, 0)
        truthy(game.printed[1]:find("saved 1 topic", 1, true), game.printed[1])
    end)

    it("a plain save stores the identity and says the other topics have no extractor yet", function()
        local game = loadAll()
        game.fire(EVENT_ADD_ON_LOADED, "ESOExporter")
        SLASH_COMMANDS["/esoexport"]("save")
        truthy(ESOExporterData.characters["4500000000000001"].topics["character.identity"])
        eq(ESOExporterData.account, nil, "no account topic has an extractor")
        truthy(game.printed[1]:find("no extractor yet", 1, true), game.printed[1])
    end)

    it("prints usage for an unknown or missing subcommand, and a problem for an unknown id", function()
        local game = loadAll()
        game.fire(EVENT_ADD_ON_LOADED, "ESOExporter")
        SLASH_COMMANDS["/esoexport"]("")
        SLASH_COMMANDS["/esoexport"]("dance")
        SLASH_COMMANDS["/esoexport"]("save character.nope")
        eq(game.printed[1], ESOExporter.Commands.USAGE)
        eq(game.printed[2], ESOExporter.Commands.USAGE)
        eq(game.printed[3], "ESOExporter: 'character.nope' is not a topic or group.")
        eq(ESOExporterData, nil, "nothing is saved")
    end)
end)
