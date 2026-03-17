-- Character Creator — Client

local isOpen      = false
local previewPed  = nil
local previewCam  = nil
local currentGender = GENDER_MALE

-- Interior-Koordinaten (MP Apartment Shell — immer verfügbar)
local CREATOR_INTERIOR = vector4(-782.0, 312.0, 85.7, 0.0)

-- ─── Kamera-Presets ──────────────────────────────────────────────────────────

local CAM_PRESETS = {
    face  = { offset = vector3(0.0,  0.55, 0.65), fov = 36.0 },
    torso = { offset = vector3(0.0,  0.8,  0.3),  fov = 45.0 },
    full  = { offset = vector3(0.0,  2.2, -0.1),  fov = 55.0 },
}
local currentCamPreset = "full"

local function SetCameraPreset(preset)
    currentCamPreset = preset
    if not previewCam or not previewPed then return end
    local p   = CAM_PRESETS[preset]
    local pos = GetEntityCoords(previewPed)
    local fwd = GetEntityForwardVector(previewPed)
    local camPos = vector3(
        pos.x + fwd.x * p.offset.y,
        pos.y + fwd.y * p.offset.y,
        pos.z + p.offset.z
    )
    SetCamCoord(previewCam, camPos.x, camPos.y, camPos.z)
    PointCamAtCoord(previewCam, pos.x, pos.y, pos.z + p.offset.z)
    SetCamFov(previewCam, p.fov)
end

-- ─── Ped erstellen ───────────────────────────────────────────────────────────

local MODELS = {
    [GENDER_MALE]   = "mp_m_freemode_01",
    [GENDER_FEMALE] = "mp_f_freemode_01",
}

local function CreatePreviewPed(gender)
    local modelName = MODELS[gender] or MODELS[GENDER_MALE]
    local model = GetHashKey(modelName)

    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end

    if previewPed and DoesEntityExist(previewPed) then
        DeleteEntity(previewPed)
    end

    local c = CREATOR_INTERIOR
    previewPed = CreatePed(4, model, c.x, c.y, c.z - 1.0, c.w, false, true)
    SetEntityVisible(previewPed, true, false)
    SetEntityInvincible(previewPed, true)
    FreezeEntityPosition(previewPed, true)
    SetBlockingOfNonTemporaryEvents(previewPed, true)
    SetPedCanRagdoll(previewPed, false)
    SetModelAsNoLongerNeeded(model)

    currentGender = gender
    return previewPed
end

-- ─── Appearance anwenden ─────────────────────────────────────────────────────

local function ApplyAppearance(ped, app)
    if not app then return end

    -- Geschlecht-Basis-Komponenten setzen
    SetPedComponentVariation(ped, 0, 0, 0, 2)   -- Gesicht
    SetPedComponentVariation(ped, 2, 0, 0, 2)   -- Haare (default)
    SetPedComponentVariation(ped, 11, 0, 0, 2)  -- Oberkörper

    -- Heritage (Eltern-Mix)
    if app.heritage then
        local h = app.heritage
        SetPedHeadBlendData(ped,
            h.mother or 0, h.father or 0, 0,
            h.mother or 0, h.father or 0, 0,
            h.resemblance or 0.5, h.skinTone or 0.5, 0.0,
            true
        )
    end

    -- Face Features (20 Morphs)
    if app.faceFeatures then
        for i, val in ipairs(app.faceFeatures) do
            SetPedFaceFeature(ped, i - 1, val)
        end
    end

    -- Head Overlays
    if app.headOverlays then
        for idx, ov in pairs(app.headOverlays) do
            SetPedHeadOverlay(ped, tonumber(idx), ov.index or 0, ov.opacity or 1.0)
            if ov.color then
                SetPedHeadOverlayColor(ped, tonumber(idx), 1, ov.color, ov.color2 or 0)
            end
        end
    end

    -- Haare
    if app.hair then
        SetPedComponentVariation(ped, 2, app.hair.style or 0, 0, 2)
        SetPedHairColor(ped, app.hair.color or 0, app.hair.highlight or 0)
    end

    -- Augenfarbe
    if app.eyeColor ~= nil then
        SetPedEyeColor(ped, app.eyeColor)
    end
end

-- ─── Creator öffnen ──────────────────────────────────────────────────────────

local function OpenCreator(charList)
    isOpen = true

    -- Spieler unsichtbar machen und einfrieren
    local playerPed = PlayerPedId()
    SetEntityVisible(playerPed, false, false)
    SetEntityInvincible(playerPed, true)
    FreezeEntityPosition(playerPed, true)
    SetPlayerControl(PlayerId(), false, 0)

    -- Zum Creator-Interior teleportieren
    SetEntityCoords(playerPed, CREATOR_INTERIOR.x, CREATOR_INTERIOR.y, CREATOR_INTERIOR.z, false, false, false, true)
    Wait(100)

    -- Loading Screen jetzt schließen — genau wie ESX in SetupCharacters().
    -- Beide Funktionen aufrufen: ShutdownLoadingScreen (legacy) +
    -- ShutdownLoadingScreenNui (neu, korrekt für loadscreen_manual_shutdown).
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()

    -- Preview-Ped erstellen
    CreatePreviewPed(GENDER_MALE)
    Wait(100)

    -- Kamera aufbauen
    previewCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    RenderScriptCams(true, true, 500, true, true)
    SetCameraPreset("full")

    -- Einblenden
    DoScreenFadeIn(400)

    -- NUI öffnen (mit Locale-Daten)
    SetNuiFocus(true, true)
    SendNUIMessage({
        type            = "open",
        charList        = charList,
        availableLangs  = Config.AvailableLanguages,
        locale          = Locales[ClientLang] or Locales['en'],
        locales         = Locales,
        langAlreadySet  = (ClientLang ~= DEFAULT_LANG),
    })

    -- Kontrollschleife
    CreateThread(function()
        while isOpen do
            DisableAllControlActions(0)
            Wait(0)
        end
    end)
end

local function CloseCreator()
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = "close" })

    if previewCam then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(previewCam, false)
        previewCam = nil
    end
    if previewPed and DoesEntityExist(previewPed) then
        DeleteEntity(previewPed)
        previewPed = nil
    end

    local playerPed = PlayerPedId()
    SetEntityVisible(playerPed, true, false)
    SetEntityInvincible(playerPed, false)
    FreezeEntityPosition(playerPed, false)
    SetPlayerControl(PlayerId(), true, 0)
end

-- ─── Events vom Server ────────────────────────────────────────────────────────

RegisterNetEvent("fivecore:showCharacterSelector", function()
    TriggerServerEvent(EVENTS.REQ_CHAR_LIST)
end)

RegisterNetEvent("fivecore:receiveCharacterList", function(charList)
    OpenCreator(charList)
end)

RegisterNetEvent("fivecore:characterCreateResult", function(result)
    if result.success then
        CloseCreator()
    else
        SendNUIMessage({ type = "createError", error = result.error })
    end
end)

-- ─── NUI Callbacks ────────────────────────────────────────────────────────────

-- Geschlecht wechseln → Ped neu spawnen
RegisterNUICallback("changeGender", function(data, cb)
    local gender = tonumber(data.gender) or GENDER_MALE
    CreatePreviewPed(gender)
    Wait(100)
    SetCameraPreset(currentCamPreset)
    cb({ ok = true })
end)

-- Appearance-Preview (live update)
RegisterNUICallback("previewAppearance", function(data, cb)
    if previewPed and DoesEntityExist(previewPed) then
        ApplyAppearance(previewPed, data.appearance)
    end
    cb({ ok = true })
end)

-- Kamera-Preset wechseln
RegisterNUICallback("setCameraPreset", function(data, cb)
    SetCameraPreset(data.preset or "full")
    cb({ ok = true })
end)

-- Charakter erstellen
RegisterNUICallback("createCharacter", function(data, cb)
    TriggerServerEvent(EVENTS.CREATE_CHAR, {
        firstname  = data.firstname,
        lastname   = data.lastname,
        dob        = data.dob,
        gender     = tonumber(data.gender),
        appearance = data.appearance,
    })
    cb({ ok = true })
end)

-- Charakter auswählen
RegisterNUICallback("selectCharacter", function(data, cb)
    TriggerServerEvent(EVENTS.SELECT_CHAR, tonumber(data.charId))
    CloseCreator()
    cb({ ok = true })
end)

-- Charakter löschen
RegisterNUICallback("deleteCharacter", function(data, cb)
    TriggerServerEvent(EVENTS.DELETE_CHAR, tonumber(data.charId))
    cb({ ok = true })
end)

-- Creator schließen (zurück zur Auswahl)
RegisterNUICallback("closeCreator", function(_, cb)
    cb({ ok = true })
end)

-- Sprache im NUI gesetzt → an Server weitergeben
RegisterNUICallback("setLanguage", function(data, cb)
    local lang = tostring(data.lang or "en"):lower()
    SetClientLang(lang)
    TriggerServerEvent("fivecore:setPlayerLanguage", lang)
    cb({ ok = true })
end)

-- Sprache vom Server empfangen → NUI aktualisieren
AddEventHandler("fivecore:languageChanged", function(lang)
    SendNUIMessage({
        type   = "setLang",
        lang   = lang,
        locale = Locales[lang] or Locales['en'],
    })
end)

