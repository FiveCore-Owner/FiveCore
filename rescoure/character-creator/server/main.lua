-- Character Creator — Server

-- Charakter-Erstellung wird an core delegiert
RegisterNetEvent("charcreator:createCharacter", function(data)
    local src = source
    TriggerEvent(EVENTS.CREATE_CHAR, src, data)
    -- tatsächlich über core events:
    TriggerNetEvent(EVENTS.CREATE_CHAR, src, data)
end)

-- Charakter auswählen
RegisterNetEvent("charcreator:selectCharacter", function(charId)
    local src = source
    TriggerNetEvent(EVENTS.SELECT_CHAR, src, charId)
end)

-- Charakter löschen
RegisterNetEvent("charcreator:deleteCharacter", function(charId)
    local src = source
    TriggerNetEvent(EVENTS.DELETE_CHAR, src, charId)
end)
