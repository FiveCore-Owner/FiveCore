-- FiveCore Anti Police
-- Vollständig deaktiviert: GTA-Polizei, Dispatch, Wanted-Level

local DISPATCH_SERVICES = 12   -- FiveM hat 12 Dispatch-Dienste (1–12)

local function DisablePolice()
    local player = PlayerId()

    -- Wanted Level nullen
    SetMaxWantedLevel(0)
    SetPlayerWantedLevel(player, 0, false)
    SetPlayerWantedLevelNoDrop(player, 0, false)
    ClearPlayerWantedLevel(player)

    -- Zufällige Cops deaktivieren
    SetCreateRandomCops(false)
    SetCreateRandomCopsNotOnScenarios(false)
    SetCreateRandomCopsOnScenarios(false)

    -- Dispatch für Spieler deaktivieren
    SetDispatchCopsForPlayer(player, false)

    -- Alle Dispatch-Dienste deaktivieren
    for i = 1, DISPATCH_SERVICES do
        EnableDispatchService(i, false)
    end
end

-- ─── Einmalig beim Start ──────────────────────────────────────────────────────

AddEventHandler("onClientResourceStart", function(res)
    if res ~= GetCurrentResourceName() then return end
    DisablePolice()
    print("[ANTIPOLICE] GTA-Polizei, Dispatch und Wanted-Level deaktiviert.")
end)

-- ─── Permanenter Thread — stellt sicher, dass es aktiv bleibt ────────────────

CreateThread(function()
    while true do
        Wait(0)

        local player = PlayerId()

        -- Wanted Level kontinuierlich nullen (Crash-safe)
        if GetPlayerWantedLevel(player) > 0 then
            SetMaxWantedLevel(0)
            SetPlayerWantedLevel(player, 0, false)
            SetPlayerWantedLevelNoDrop(player, 0, false)
            ClearPlayerWantedLevel(player)
        end

        -- Dispatch-Block aufrechterhalten
        SetDispatchCopsForPlayer(player, false)

        -- Cops aus Fahrzeugen halten
        DisableControlAction(0, 19, true)  -- Polizei-Radio deaktivieren
    end
end)
