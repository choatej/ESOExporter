-- Hand-built fixture for schema v1. It is NOT output from the add-on (none exists yet) and
-- holds no real character or account data. The topics fixture.long_text and fixture.dropped are
-- synthetic: they exist to exercise $parts strings and the report's dropped list. Replace this
-- file with scrubbed real output once the add-on produces some.
-- Written the way the game writes SavedVariables: one global assignment, tab indented.
ESOExporterData =
{
	["meta"] = {
		["schema"] = 1,
		["addon"] = "ESOExporter",
		["addonVersion"] = "0.1.0",
		["apiVersion"] = 101051,
		["gameVersion"] = "eso.live.12.1.7.3318083",
		["server"] = "NA Megaserver",
	},
	["account"] = {
		["topics"] = {
			["account.currency"] = {
				["kind"] = "data",
				["timestamp"] = 1795000000,
				["data"] = {
					["balances"] = {
						{
							["currency"] = 1,
							["amount"] = 12345,
						},
						{
							["currency"] = 2,
							["amount"] = 678,
						},
					},
				},
				["report"] = {
					["tables"] = 4,
					["strings"] = 0,
					["longStrings"] = 0,
					["numbers"] = 4,
					["booleans"] = 0,
					["nodes"] = 8,
					["stringBytes"] = 36,
					["dropped"] = 0,
					["droppedList"] = {
					},
					["truncated"] = false,
				},
			},
		},
	},
	["characters"] = {
		["4500000000000001"] = {
			["name"] = "Test Character One",
			["topics"] = {
				["character.identity"] = {
					["kind"] = "data",
					["timestamp"] = 1795000000,
					["data"] = {
						["raceId"] = 1,
						["classId"] = 2,
						["level"] = 50,
						["championPoints"] = 810,
						["alliance"] = 1,
						["gender"] = 2,
					},
					["report"] = {
						["tables"] = 1,
						["strings"] = 0,
						["longStrings"] = 0,
						["numbers"] = 6,
						["booleans"] = 0,
						["nodes"] = 7,
						["stringBytes"] = 46,
						["dropped"] = 0,
						["droppedList"] = {
						},
						["truncated"] = false,
					},
				},
			},
		},
		["4500000000000002"] = {
			["name"] = "Test Character Two",
			["topics"] = {
				["character.identity"] = {
					["kind"] = "data",
					["timestamp"] = 1795000060,
					["data"] = {
						["raceId"] = 5,
						["classId"] = 1,
						["level"] = 12,
						["championPoints"] = 0,
						["alliance"] = 3,
						["gender"] = 1,
					},
					["report"] = {
						["tables"] = 1,
						["strings"] = 0,
						["longStrings"] = 0,
						["numbers"] = 6,
						["booleans"] = 0,
						["nodes"] = 7,
						["stringBytes"] = 46,
						["dropped"] = 0,
						["droppedList"] = {
						},
						["truncated"] = false,
					},
				},
				["fixture.long_text"] = {
					["kind"] = "data",
					["timestamp"] = 1795000060,
					["data"] = {
						["text"] = {
							["$parts"] = {
								"First line of a synthetic long string.\n",
								"Second line, kept whole when it fits.\n",
								"Third line ends the text.\n",
							},
						},
					},
					["report"] = {
						["tables"] = 1,
						["strings"] = 0,
						["longStrings"] = 1,
						["numbers"] = 0,
						["booleans"] = 0,
						["nodes"] = 2,
						["stringBytes"] = 107,
						["dropped"] = 0,
						["droppedList"] = {
						},
						["truncated"] = false,
					},
				},
				["fixture.dropped"] = {
					["kind"] = "data",
					["timestamp"] = 1795000060,
					["data"] = {
						["count"] = 3,
						["enabled"] = true,
					},
					["report"] = {
						["tables"] = 1,
						["strings"] = 0,
						["longStrings"] = 0,
						["numbers"] = 1,
						["booleans"] = 1,
						["nodes"] = 3,
						["stringBytes"] = 20,
						["dropped"] = 1,
						["droppedList"] = {
							"callback (function)",
						},
						["truncated"] = false,
					},
				},
			},
		},
	},
}
