-- FiveCore Death Screen — Server

-- Respawn-Koordinaten (Krankenhaus + Notaufnahme)
local RESPAWN_LOCATIONS = {
    { x = 295.9348, y = -584.2498, z = 43.2843, w = 45.0 },    -- Pillbox Hill Medical
    { x = 1839.5576, y = 3672.8120, z = 34.2810, w = 210.0 },  -- Sandy Shores Medical
    { x = -449.5107, y = -340.3773, z = 34.5018, w = 116.0 },  -- Rockford Hills Medical
}

local function GetRespawnCoords()
    return RESPAWN_LOCATIONS[math.random(#RESPAWN_LOCATIONS)]
end

-- ─── Prüfen ob Sanitäter online ──────────────────────────────────────────────

local function GetOnlineAmbulanceCount()
    local count = 0
    for src, p in pairs(Players) do
        if p and p.character and p.character.job then
            local jobName = type(p.character.job) == "table"
                and (p.character.job.name or "")
                or tostring(p.character.job)
            if jobName == "ambulance" or jobName == "medic" or jobName == "ems" then
                count = count + 1
            end
        end
    end
    return count
end

-- ─── Respawn (Timer abgelaufen oder manuell) ─────────────────────────────────

RegisterNetEvent("deathscreen:respawn", function()
    local src = source
    if not Players[src] or not Players[src].character then return end

    if not FC_Security.RateLimit(src, "respawn", 1, 20000) then
        FC_Security.Warn(src, "deathscreen:respawn rate limit")
        return
    end

    local coords = GetRespawnCoords()
    TriggerClientEvent("deathscreen:doRespawn", src, coords)
    DB.Log(src, "player_respawned", { method = "timer", x = coords.x, y = coords.y, z = coords.z })

    if Config.Debug then
        print(string.format("[DEATH] Spieler %d respawnt bei %.1f %.1f %.1f", src, coords.x, coords.y, coords.z))
    end
end)

-- ─── Sanitäter rufen [911] ────────────────────────────────────────────────────

RegisterNetEvent("deathscreen:callAmbulance", function()
    local src = source
    local p   = Players[src]
    if not p or not p.character then return end

    if not FC_Security.RateLimit(src, "call_ambulance", 1, 60000) then
        FC_Security.Warn(src, "deathscreen:callAmbulance rate limit")
        return
    end

    local name         = p.character.fullname or "Unbekannt"
    local ambCount     = GetOnlineAmbulanceCount()

    DB.Log(src, "ambulance_called", { player = name, ambulanceOnline = ambCount })

    if ambCount == 0 then
        -- Kein Sanitäter online → NPC-Krankenwagen (Auto-Respawn nach 30s)
        TriggerClientEvent(EVENTS.NOTIFY, src, {
            text = "Kein Sanitäter verfügbar. NPC-Krankenwagen unterwegs (30s)...",
            type = NOTIFY_TYPES.WARNING,
        })

        CreateThread(function()
            Wait(30000)
            -- Prüfen ob Spieler noch da und tot
            if Players[src] and Players[src].character then
                local coords = GetRespawnCoords()
                TriggerClientEvent("deathscreen:doRespawn", src, coords)
                DB.Log(src, "npc_ambulance_respawn", { player = name })
                if Config.Debug then print("[DEATH] NPC-Ambulanz hat " .. name .. " wiederbelebt.") end
            end
        end)
    else
        -- Sanitäter benachrichtigen
        for tarSrc, tarP in pairs(Players) do
            if tarP and tarP.character and tarP.character.job then
                local jobName = type(tarP.character.job) == "table"
                    and (tarP.character.job.name or "")
                    or tostring(tarP.character.job)
                if jobName == "ambulance" or jobName == "medic" or jobName == "ems" then
                    TriggerClientEvent(EVENTS.NOTIFY, tarSrc, {
                        text = string.format("[911] %s benötigt medizinische Hilfe!", name),
                        type = NOTIFY_TYPES.WARNING,
                    })
                end
            end
        end

        TriggerClientEvent(EVENTS.NOTIFY, src, {
            text = string.format("%d Sanitäter(in) wurde(n) benachrichtigt.", ambCount),
            type = NOTIFY_TYPES.INFO,
        })
    end
end)
