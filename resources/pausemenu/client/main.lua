-- FiveCore Pause Menu

local pauseOpen    = false
local playerLoaded = false

-- ─── Spieler geladen ──────────────────────────────────────────────────────────

AddEventHandler("fivecore:localPlayerSpawned", function()
    playerLoaded = true
end)

-- ─── Pause Menü öffnen ────────────────────────────────────────────────────────

local function OpenPause()
    if pauseOpen then return end
    pauseOpen = true

    -- Bewegung einfrieren
    SetEntityInvincible(PlayerPedId(), true)

    -- Karte aufklappen
    SetBigmapActive(true, false)
    SetRadarBigmapEnabled(true, false)

    -- Spieler-Daten sammeln
    local ped      = PlayerPedId()
    local hp       = math.max(0, math.floor(((GetEntityHealth(ped) - 100) / 100) * 100))
    local armour   = GetPedArmour(ped)
    local coords   = GetEntityCoords(ped)
    local heading  = GetEntityHeading(ped)
    local h, m     = GetClockHours(), GetClockMinutes()
    local time     = string.format("%02d:%02d", h, m)
    local zone     = GetNameOfZone(coords.x, coords.y, coords.z)
    local players  = GetActivePlayers()
    local playerCount = 0
    for _ in pairs(players) do playerCount = playerCount + 1 end

    -- Server-Titel
    local servTitle = GetConvar("hudtitle", "FiveCore RP")
    local locale    = Locales[ClientLang] or Locales['en']

    SetNuiFocus(true, true)
    SendNUIMessage({
        type        = "show",
        servTitle   = servTitle,
        time        = time,
        zone        = zone,
        health      = hp,
        armour      = armour,
        coords      = { x = math.floor(coords.x), y = math.floor(coords.y), z = math.floor(coords.z) },
        heading     = math.floor(heading),
        playerCount = playerCount,
        locale      = locale,
    })
end

local function ClosePause()
    if not pauseOpen then return end
    pauseOpen = false

    SetBigmapActive(false, false)
    SetRadarBigmapEnabled(false, false)
    SetEntityInvincible(PlayerPedId(), false)

    SetNuiFocus(false, false)
    SendNUIMessage({ type = "hide" })
end

-- ─── NUI Callback ────────────────────────────────────────────────────────────

RegisterNUICallback("closePause", function(_, cb)
    ClosePause()
    cb({})
end)

-- ─── P-Taste erkennen ────────────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(0)

        if pauseOpen then
            -- Alle Eingaben außer ESC blockieren wenn Pause offen
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)   -- Maus X
            EnableControlAction(0, 2, true)   -- Maus Y
            EnableControlAction(0, 25, true)  -- Maus klick
        end

        if not playerLoaded then goto pskip end

        -- P-Taste (INPUT_FRONTEND_PAUSE_ALTERNATE = 199)
        if IsDisabledControlJustReleased(0, 199) or IsControlJustReleased(0, 199) then
            if pauseOpen then
                ClosePause()
            else
                OpenPause()
            end
        end

        ::pskip::
    end
end)

-- ─── Sprache geändert ────────────────────────────────────────────────────────

AddEventHandler("fivecore:languageChanged", function(lang)
    if pauseOpen then
        SendNUIMessage({ type = "setLang", locale = Locales[lang] or Locales['en'] })
    end
end)
