-- character.identity: who the character is, as raw ids and numbers. Names (race, class, alliance)
-- are resolved in post-processing from these ids; nothing here is formatted.
--
-- Checked in game on API 101051 (12.1.7): every call returned a number.

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
