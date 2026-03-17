-- FiveCore Client State
-- Lokaler Spieler-State (nur für diesen Client)

-- ─── Sprache setzen ───────────────────────────────────────────────────────────

RegisterNetEvent("fivecore:setLanguage", function(lang)
    SetClientLang(lang)
    TriggerEvent("fivecore:languageChanged", lang)
    -- Alle offenen NUIs informieren
    SendNUIMessage({ type = "setLang", lang = lang, locale = Locales[lang] or Locales['en'] })
    if Config.Debug then print("[CORE] Sprache gesetzt: " .. lang) end
end)

LocalPlayer = {
    character = nil,     -- { id, firstname, lastname, gender, phone, ... }
    money     = { cash = 0, bank = 0 },
    status    = { hunger = 100, thirst = 100, stress = 0 },
    state     = CHARACTER_STATES.IDLE,
    loaded    = false,
}

-- ─── Listener: Charakter geladen ─────────────────────────────────────────────

RegisterNetEvent(EVENTS.PLAYER_LOADED, function(data)
    LocalPlayer.character = data.character
    LocalPlayer.money     = data.money
    LocalPlayer.state     = CHARACTER_STATES.LOADED
    LocalPlayer.loaded    = true
    if data.character.status then
        LocalPlayer.status = data.character.status
    end
    TriggerEvent("fivecore:localPlayerLoaded", data)
end)

-- ─── Listener: Geld ──────────────────────────────────────────────────────────

RegisterNetEvent(EVENTS.MONEY_UPDATED, function(data)
    LocalPlayer.money = data
    TriggerEvent("fivecore:localMoneyUpdated", data)
end)

-- ─── Listener: Status ────────────────────────────────────────────────────────

RegisterNetEvent(EVENTS.STATUS_UPDATED, function(data)
    LocalPlayer.status = data
    TriggerEvent("fivecore:localStatusUpdated", data)
end)

-- ─── Listener: Notify ────────────────────────────────────────────────────────

RegisterNetEvent(EVENTS.NOTIFY, function(data)
    TriggerEvent("fivecore:showNotify", data)
end)

-- ─── Position periodisch speichern ───────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(60000) -- jede Minute
        if LocalPlayer.loaded then
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local h   = GetEntityHeading(ped)
            TriggerServerEvent(EVENTS.SAVE_POSITION, {
                x = pos.x, y = pos.y, z = pos.z, h = h
            })
        end
    end
end)

-- ─── Status periodisch senden ────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(Config.StatusTickInterval + 5000)
        if LocalPlayer.loaded then
            TriggerServerEvent(EVENTS.SYNC_STATUS, LocalPlayer.status)
        end
    end
end)

-- ─── Debug-Teleport ──────────────────────────────────────────────────────────

RegisterNetEvent("fivecore:debugTeleport", function(coords)
    local ped = PlayerPedId()
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, true)
end)
