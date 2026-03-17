-- Spawn-Selector Client

local isOpen = false

-- ─── Appearance auf Ped anwenden ─────────────────────────────────────────────

local function ApplyCharacterAppearance(ped, app)
    if not app or type(app) ~= "table" then return end

    SetPedComponentVariation(ped, 0, 0, 0, 2)
    SetPedComponentVariation(ped, 2, 0, 0, 2)
    SetPedComponentVariation(ped, 11, 0, 0, 2)

    if app.heritage then
        local h = app.heritage
        SetPedHeadBlendData(ped,
            h.mother or 0, h.father or 0, 0,
            h.mother or 0, h.father or 0, 0,
            h.resemblance or 0.5, h.skinTone or 0.5, 0.0,
            true
        )
    end

    if app.faceFeatures then
        for i, val in ipairs(app.faceFeatures) do
            SetPedFaceFeature(ped, i - 1, val)
        end
    end

    if app.headOverlays then
        for idx, ov in pairs(app.headOverlays) do
            SetPedHeadOverlay(ped, tonumber(idx), ov.index or 0, ov.opacity or 1.0)
            if ov.color then
                SetPedHeadOverlayColor(ped, tonumber(idx), 1, ov.color, ov.color2 or 0)
            end
        end
    end

    if app.hair then
        SetPedComponentVariation(ped, 2, app.hair.style or 0, 0, 2)
        SetPedHairColor(ped, app.hair.color or 0, app.hair.highlight or 0)
    end

    if app.eyeColor ~= nil then
        SetPedEyeColor(ped, app.eyeColor)
    end
end

-- ─── Spawn-UI öffnen ─────────────────────────────────────────────────────────

RegisterNetEvent("fivecore:doSpawn")
AddEventHandler("fivecore:doSpawn", function(data)
    local coords     = data.coords
    local gender     = data.gender or 0
    local appearance = data.appearance

    -- Ausblenden bevor Teleport (sauber, kein Flackern)
    DoScreenFadeOut(500)
    while IsScreenFadingOut() do Wait(100) end

    -- Spieler-Modell auf MP-Freemode setzen
    local modelName = (gender == 1) and "mp_f_freemode_01" or "mp_m_freemode_01"
    local model     = GetHashKey(modelName)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(100) end
    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)

    -- Spieler am Spawn-Punkt wiederbeleben + teleportieren
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, coords.w or 0.0, true, false)

    local ped = PlayerPedId()
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, true)
    SetEntityHeading(ped, coords.w or 0.0)

    -- Aussehen anwenden
    ApplyCharacterAppearance(ped, appearance)

    -- Sichtbar, beweglich, verwundbar
    SetEntityVisible(ped, true, false)
    SetEntityInvincible(ped, false)
    FreezeEntityPosition(ped, false)
    SetPlayerControl(PlayerId(), true, 0)

    Wait(200)
    DoScreenFadeIn(750)

    TriggerEvent("fivecore:localPlayerSpawned")

    if Config.Debug then
        print(string.format("[SPAWN] Gespawnt bei: %.1f %.1f %.1f (Model: %s)", coords.x, coords.y, coords.z, modelName))
    end
end)

-- ─── Charakter geladen → Spawn-Auswahl zeigen ────────────────────────────────

RegisterNetEvent("fivecore:playerDataLoaded")
AddEventHandler("fivecore:playerDataLoaded", function()
    Wait(300)
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
