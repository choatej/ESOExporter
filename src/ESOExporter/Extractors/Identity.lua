-- character.identity: who the character is, as raw ids and numbers. Names (race, class, alliance)
-- are resolved in post-processing from these ids; nothing here is formatted.
--
-- The game calls below are unverified against the live API (101051): check each in game, as the
-- pull request notes say, before relying on the output.

local TAG = "player"

ESOExporter.Register("character.identity", function()
    return {
        raceId = GetUnitRaceId(TAG),
        classId = GetUnitClassId(TAG),
        gender = GetUnitGender(TAG),
        alliance = GetUnitAlliance(TAG),
        level = GetUnitLevel(TAG),
        championPoints = GetPlayerChampionPointsEarned(),
    }
end)
