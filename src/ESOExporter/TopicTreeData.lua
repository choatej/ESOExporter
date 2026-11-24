-- GENERATED from schema/v1/tree.json by tools/python/scripts/gen_tree_lua.py. Do not edit.
-- Edit tree.json, then run `python3 tools/python/scripts/gen_tree_lua.py`. A test fails when
-- this file is out of date.

ESOExporter = ESOExporter or {}
ESOExporter.TopicTreeData = {
    version = 1,
    nodes = {
        {
            id = "account",
            type = "group",
            label = "Account",
            default = true,
            children = {
                {
                    id = "account.currency",
                    type = "topic",
                    label = "Currencies",
                    default = true,
                    scope = "account",
                    cost = "light",
                },
                {
                    id = "account.inventory",
                    type = "group",
                    label = "Account storage",
                    default = true,
                    children = {
                        {
                            id = "account.inventory.bank",
                            type = "topic",
                            label = "Bank",
                            default = false,
                            scope = "account",
                            cost = "heavy",
                        },
                        {
                            id = "account.inventory.craft_bag",
                            type = "topic",
                            label = "Craft bag",
                            default = false,
                            scope = "account",
                            cost = "heavy",
                        },
                    },
                },
                {
                    id = "account.achievements",
                    type = "topic",
                    label = "Achievements",
                    default = false,
                    scope = "account",
                    cost = "heavy",
                },
            },
        },
        {
            id = "character",
            type = "group",
            label = "Character",
            default = true,
            children = {
                {
                    id = "character.identity",
                    type = "topic",
                    label = "Identity",
                    description = "Race, class, level, alliance and gender.",
                    default = true,
                    scope = "character",
                    cost = "light",
                },
                {
                    id = "character.stats",
                    type = "group",
                    label = "Stats",
                    default = true,
                    children = {
                        {
                            id = "character.stats.attributes",
                            type = "topic",
                            label = "Attribute points",
                            default = true,
                            scope = "character",
                            cost = "light",
                        },
                        {
                            id = "character.stats.resources",
                            type = "topic",
                            label = "Health, magicka and stamina",
                            default = true,
                            scope = "character",
                            cost = "light",
                        },
                        {
                            id = "character.stats.offense",
                            type = "topic",
                            label = "Offensive stats",
                            default = true,
                            scope = "character",
                            cost = "light",
                        },
                        {
                            id = "character.stats.defense",
                            type = "topic",
                            label = "Defensive stats",
                            default = true,
                            scope = "character",
                            cost = "light",
                        },
                    },
                },
                {
                    id = "character.equipment",
                    type = "group",
                    label = "Equipment",
                    default = true,
                    children = {
                        {
                            id = "character.equipment.worn",
                            type = "topic",
                            label = "Worn gear",
                            default = true,
                            scope = "character",
                            cost = "light",
                        },
                        {
                            id = "character.equipment.quickslots",
                            type = "topic",
                            label = "Quickslots",
                            default = true,
                            scope = "character",
                            cost = "light",
                        },
                    },
                },
                {
                    id = "character.skills",
                    type = "group",
                    label = "Skills",
                    default = true,
                    children = {
                        {
                            id = "character.skills.lines",
                            type = "topic",
                            label = "Skill lines",
                            default = true,
                            scope = "character",
                            cost = "light",
                        },
                        {
                            id = "character.skills.bars",
                            type = "topic",
                            label = "Skill bars",
                            default = true,
                            scope = "character",
                            cost = "light",
                        },
                    },
                },
                {
                    id = "character.champion_points",
                    type = "group",
                    label = "Champion points",
                    default = true,
                    children = {
                        {
                            id = "character.champion_points.assigned",
                            type = "topic",
                            label = "Assigned points",
                            default = true,
                            scope = "character",
                            cost = "light",
                        },
                        {
                            id = "character.champion_points.slotted",
                            type = "topic",
                            label = "Slotted stars",
                            default = true,
                            scope = "character",
                            cost = "light",
                        },
                    },
                },
                {
                    id = "character.inventory",
                    type = "group",
                    label = "Character inventory",
                    default = true,
                    children = {
                        {
                            id = "character.inventory.backpack",
                            type = "topic",
                            label = "Backpack",
                            default = false,
                            scope = "character",
                            cost = "heavy",
                        },
                    },
                },
            },
        },
    },
}

return ESOExporter.TopicTreeData
