-- Spawn-Selector Server
-- Der eigentliche Spawn wird in core/events.lua verarbeitet (EVENTS.REQ_SPAWN)
-- Hier nur Hilfsfunktionen falls nötig.

-- Spawn-Punkte an Client senden
RegisterNetEvent("spawn:requestSpawnList", function()
    local src = source
    local list = {}
    for i, s in ipairs(Config.Spawns) do
        table.insert(list, { index = i, label = s.label })
    end
    TriggerClientEvent("spawn:receiveSpawnList", src, list)
end)
