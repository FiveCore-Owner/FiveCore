-- FiveCore Weapon Shop — Client

local shopOpen       = false
local playerLoaded   = false
local trainingActive = false
local trainingKills  = 0
local trainingNPCs   = {}
local prevPos        = nil   -- Position vor dem Training

-- ─── Koordinaten ─────────────────────────────────────────────────────────────

local SHOP_MARKER    = vector3(22.1929, -1107.3643, 29.7970)
local NPC_COORDS     = vector4(23.0138, -1104.9580, 29.7970, 160.8784)
local INTERACT_DIST  = 3.0
local TRAINING_SPAWN = vector4(13.3521, -1097.1472, 29.8347, 336.8491)

-- 20 NPCs verteilt auf 3 Bereiche
local NPC_SPAWN_ZONES = {
    { x = 18.5146, y = -1068.5146, z = 29.7970 },
    { x = 22.8716, y = -1069.9816, z = 29.7970 },
    { x = 27.7627, y = -1071.6415, z = 29.7970 },
}

-- ─── Spieler-Status ──────────────────────────────────────────────────────────

AddEventHandler("fivecore:localPlayerSpawned", function()
    playerLoaded = true
end)

-- ─── NPC spawnen ─────────────────────────────────────────────────────────────

local shopNPC = nil
local NPC_MODEL = "s_m_y_ammucity_01"

local function SpawnShopNPC()
    local model = GetHashKey(NPC_MODEL)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(100) end

    shopNPC = CreatePed(4, model, NPC_COORDS.x, NPC_COORDS.y, NPC_COORDS.z - 1.0, NPC_COORDS.w, false, true)
    SetEntityInvincible(shopNPC, true)
    FreezeEntityPosition(shopNPC, true)
    SetBlockingOfNonTemporaryEvents(shopNPC, true)
    SetPedFleeAttributes(shopNPC, 0, false)
    SetPedCanRagdoll(shopNPC, false)
    SetModelAsNoLongerNeeded(model)

    RequestAnimDict("amb@world_human_stand_impatient@male@no_sign@idle_a")
    while not HasAnimDictLoaded("amb@world_human_stand_impatient@male@no_sign@idle_a") do Wait(100) end
    TaskPlayAnim(shopNPC, "amb@world_human_stand_impatient@male@no_sign@idle_a", "idle_a", 8.0, -8.0, -1, 1, 0, false, false, false)

    if Config.Debug then print("[WEAPONSHOP] NPC gespawnt") end
end

-- ─── Shop öffnen / schließen ─────────────────────────────────────────────────

local function OpenShop()
    shopOpen = true
    SetNuiFocus(true, true)
    TriggerServerEvent("weaponshop:open")
end

local function CloseShop()
    shopOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = "close" })
end

-- ─── NUI Callbacks ───────────────────────────────────────────────────────────

RegisterNUICallback("closeShop", function(_, cb)
    CloseShop()
    cb({})
end)

RegisterNUICallback("buyLicense", function(_, cb)
    TriggerServerEvent("weaponshop:buyLicense")
    cb({ ok = true })
end)

RegisterNUICallback("buyWeapon", function(data, cb)
    TriggerServerEvent("weaponshop:buyWeapon", data)
    cb({ ok = true })
end)

RegisterNUICallback("startTraining", function(_, cb)
    CloseShop()
    TriggerServerEvent("weaponshop:startTraining")
    cb({ ok = true })
end)

RegisterNUICallback("exitTraining", function(_, cb)
    if trainingActive then
        EndTraining(false)
    end
    cb({ ok = true })
end)

-- ─── Server Antworten ────────────────────────────────────────────────────────

RegisterNetEvent("weaponshop:receiveData", function(data)
    SendNUIMessage({
        type     = "open",
        hasLicense     = data.hasLicense,
        licensePrice   = data.licensePrice,
        weapons        = data.weapons,
        locale         = Locales[ClientLang] or Locales['en'],
    })
end)

RegisterNetEvent("weaponshop:result", function(data)
    SendNUIMessage({ type = "result", data = data })
end)

RegisterNetEvent("weaponshop:giveWeapon", function(weaponName)
    local hash = GetHashKey(weaponName)
    GiveWeaponToPed(PlayerPedId(), hash, 250, false, true)
end)

AddEventHandler("fivecore:languageChanged", function(lang)
    SendNUIMessage({ type = "setLang", locale = Locales[lang] or Locales['en'] })
end)

-- ─── Training Range ──────────────────────────────────────────────────────────

local function SpawnTrainingNPCs()
    trainingNPCs = {}
    local models = { "a_m_y_hipster_01", "a_m_m_business_01", "a_m_y_genstreet_01", "a_m_m_fatcult_01", "a_m_y_mexthug_01" }
    local totalSpawned = 0

    for _, zone in ipairs(NPC_SPAWN_ZONES) do
        for i = 1, 7 do  -- ~7 pro Zone = ~21, aber max 20
            if totalSpawned >= 20 then break end

            local modelName = models[math.random(#models)]
            local model     = GetHashKey(modelName)
            RequestModel(model)
            while not HasModelLoaded(model) do Wait(100) end

            -- Leicht zufällige Position um den Spawn-Punkt
            local offsetX = zone.x + math.random(-300, 300) / 100.0
            local offsetY = zone.y + math.random(-300, 300) / 100.0

            local ped = CreatePed(4, model, offsetX, offsetY, zone.z - 1.0, math.random(0, 360), true, false)
            SetPedArmour(ped, 0)
            SetEntityHealth(ped, 100)    -- leichte NPCs (1 Schuss)
            SetPedAsCop(ped, false)
            SetPedFleeAttributes(ped, 0, false)
            SetBlockingOfNonTemporaryEvents(ped, false)
            SetPedCombatAbility(ped, 0)  -- keine Gegenwehr
            SetPedCanRagdoll(ped, true)
            SetModelAsNoLongerNeeded(model)

            -- Passive stehen oder rumlaufen
            TaskWanderInArea(ped, zone.x, zone.y, zone.z, 8.0, 1.0, 0)

            table.insert(trainingNPCs, ped)
            totalSpawned = totalSpawned + 1
        end
        if totalSpawned >= 20 then break end
    end

    if Config.Debug then print("[WEAPONSHOP] " .. totalSpawned .. " Training-NPCs gespawnt") end
end

local function CleanupTrainingNPCs()
    for _, ped in ipairs(trainingNPCs) do
        if DoesEntityExist(ped) then
            DeletePed(ped)
        end
    end
    trainingNPCs = {}
end

local function EndTraining(success)
    trainingActive = false

    -- Kamera / Steuerung wiederherstellen
    SetNuiFocus(false, false)
    SetEntityInvincible(PlayerPedId(), false)
    FreezeEntityPosition(PlayerPedId(), false)
    SetPlayerControl(PlayerId(), true, 0)
    DisplayHud(false)
    DisplayRadar(true)

    CleanupTrainingNPCs()

    -- Zurück teleportieren
    local ped = PlayerPedId()
    DoScreenFadeOut(500)
    Wait(500)
    if prevPos then
        SetEntityCoords(ped, prevPos.x, prevPos.y, prevPos.z, false, false, false, true)
        SetEntityHeading(ped, prevPos.w or 0.0)
    end
    DoScreenFadeIn(750)

    if success then
        TriggerServerEvent("weaponshop:trainingComplete", { kills = trainingKills })
    else
        TriggerClientEvent(EVENTS and EVENTS.NOTIFY or "fivecore:notify", "fivecore:notify", {
            text = "Training abgebrochen.",
            type = "info",
        })
    end

    trainingKills = 0
    SendNUIMessage({ type = "trainingEnd" })
end

-- Training starten (Server hat bestätigt)
RegisterNetEvent("weaponshop:beginTraining", function()
    trainingActive = true
    trainingKills  = 0

    local ped = PlayerPedId()
    prevPos   = GetEntityCoords(ped)
    prevPos   = { x = prevPos.x, y = prevPos.y, z = prevPos.z, w = GetEntityHeading(ped) }

    -- Zum Trainingsbereich teleportieren
    DoScreenFadeOut(500)
    Wait(500)
    SetEntityCoords(ped, TRAINING_SPAWN.x, TRAINING_SPAWN.y, TRAINING_SPAWN.z, false, false, false, true)
    SetEntityHeading(ped, TRAINING_SPAWN.w)
    DoScreenFadeIn(500)

    -- Spieler einfrieren (nur Kamera kann bewegt werden)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)

    -- Pistole geben für das Training
    GiveWeaponToPed(ped, GetHashKey("WEAPON_PISTOL"), 100, false, true)

    Wait(500)
    SpawnTrainingNPCs()

    -- Training UI anzeigen
    SetNuiFocus(false, false)  -- Maus für Schießen frei
    SendNUIMessage({ type = "trainingStart", required = 10 })

    if Config.Debug then print("[WEAPONSHOP] Training gestartet") end
end)

-- Training erfolgreich
RegisterNetEvent("weaponshop:trainingSuccess", function()
    -- Bereits in EndTraining behandelt
end)

-- Training fehlgeschlagen (Server-Validierung)
RegisterNetEvent("weaponshop:trainingFailed", function()
    SendNUIMessage({ type = "trainingFail" })
end)

-- ─── Training Kill-Detection ──────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(500)
        if not trainingActive then goto tskip end

        -- Kills zählen (tote NPCs)
        local newKills = 0
        for _, ped in ipairs(trainingNPCs) do
            if DoesEntityExist(ped) and IsEntityDead(ped) then
                newKills = newKills + 1
            end
        end

        if newKills ~= trainingKills then
            trainingKills = newKills
            SendNUIMessage({ type = "trainingKills", kills = trainingKills, required = 10 })

            if trainingKills >= 10 then
                -- Alle 10 Kills erreicht → Training beenden
                Wait(1000)
                EndTraining(true)
            end
        end

        ::tskip::
    end
end)

-- ─── Proximity Tick ──────────────────────────────────────────────────────────

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(1000) end
    SpawnShopNPC()

    while true do
        Wait(0)

        if not playerLoaded or trainingActive then goto wskip end

        local ped    = PlayerPedId()
        local pos    = GetEntityCoords(ped)
        local dist   = #(pos - SHOP_MARKER)

        if dist < INTERACT_DIST and not shopOpen then
            local locale = Locales[ClientLang] or Locales['en']
            DrawText3D(NPC_COORDS.x, NPC_COORDS.y, NPC_COORDS.z + 1.1,
                (locale and locale['weaponshop_interact']) or "Press [E] to open Weapon Shop")

            if IsControlJustReleased(0, 38) then -- E
                OpenShop()
            end
        end

        ::wskip::
    end
end)

-- ─── DrawText3D ──────────────────────────────────────────────────────────────

function DrawText3D(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.0, 0.28)
    SetTextFont(4)
    SetTextColour(255, 255, 255, 220)
    SetTextOutline()
    SetTextCentre(true)
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(sx, sy)
    local factor = #text / 370
    DrawRect(sx, sy + 0.0125, 0.015 + factor, 0.03, 0, 0, 0, 75)
end
