-- Spawn-Selector Client

local isOpen = false

-- ─── Spawn-UI öffnen ─────────────────────────────────────────────────────────

RegisterNetEvent("fivecore:doSpawn", function(data)
    local coords = data.coords
    local ped    = PlayerPedId()

    -- Spieler zum Spawn-Punkt teleportieren
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, true)
    Wait(100)
    SetEntityHeading(ped, coords.w or 0.0)

    -- Spieler sichtbar + beweglich machen
    SetEntityVisible(ped, true, false)
    SetEntityInvincible(ped, false)
    FreezeEntityPosition(ped, false)

    -- Respawn-Fade
    DoScreenFadeOut(0)
    Wait(500)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, coords.w, true, false)
    TriggerEvent("playerSpawned")
    DoScreenFadeIn(500)

    TriggerEvent("fivecore:localPlayerLoaded")
    if Config.Debug then
        print("[SPAWN] Gespawnt bei: " .. coords.x .. " " .. coords.y .. " " .. coords.z)
    end
end)

-- ─── Charakter geladen → Spawn-Auswahl zeigen ────────────────────────────────

AddEventHandler(EVENTS.PLAYER_LOADED, function()
    Wait(500)
    OpenSpawnSelector()
end)

function OpenSpawnSelector()
    isOpen = true
    TriggerServerEvent("spawn:requestSpawnList")
end

RegisterNetEvent("spawn:receiveSpawnList", function(list)
    SetNuiFocus(true, true)
    SendNUIMessage({
        type   = "open",
        spawns = list,
        locale = Locales[ClientLang] or Locales['en'],
    })
end)

AddEventHandler("fivecore:languageChanged", function(lang)
    SendNUIMessage({ type = "setLang", locale = Locales[lang] or Locales['en'] })
end)

-- ─── NUI Callbacks ───────────────────────────────────────────────────────────

RegisterNUICallback("selectSpawn", function(data, cb)
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = "close" })
    TriggerServerEvent(EVENTS.REQ_SPAWN, tonumber(data.index))
    cb({ ok = true })
end)
