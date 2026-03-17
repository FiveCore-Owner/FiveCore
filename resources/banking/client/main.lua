-- FiveCore Banking — Client

local bankOpen   = false
local nearNPC    = false
local nearATM    = false
local bankerPed  = nil

-- ─── Konfiguration ───────────────────────────────────────────────────────────

local BANKER_COORDS = vector4(148.0977, -1041.6658, 29.3679, 345.0763)
local ATM_COORDS    = vector4(150.0399, -1040.7798, 29.3741, 158.5270)
local ATM_MODELS    = { "prop_atm_01", "prop_atm_02", "prop_atm_03", "prop_atm_04" }
local INTERACT_DIST = 2.5   -- Meter zum Banker / ATM

-- ─── Spieler-Status ──────────────────────────────────────────────────────────

-- playerLoaded via NetworkIsPlayerActive() polling — handles late resource start

-- ─── Banker NPC spawnen ───────────────────────────────────────────────────────

local function SpawnBanker()
    local model = GetHashKey("s_m_m_bank_01")
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(100) end

    bankerPed = CreatePed(4, model, BANKER_COORDS.x, BANKER_COORDS.y, BANKER_COORDS.z - 1.0, BANKER_COORDS.w, false, true)
    SetEntityInvincible(bankerPed, true)
    FreezeEntityPosition(bankerPed, true)
    SetBlockingOfNonTemporaryEvents(bankerPed, true)
    SetPedFleeAttributes(bankerPed, 0, false)
    SetPedCanRagdoll(bankerPed, false)
    SetPedRelationshipGroupHash(bankerPed, GetHashKey("CIVMALE"))
    SetModelAsNoLongerNeeded(model)

    -- Idle-Animation
    RequestAnimDict("amb@world_human_clipboard@male@idle_a")
    while not HasAnimDictLoaded("amb@world_human_clipboard@male@idle_a") do Wait(100) end
    TaskPlayAnim(bankerPed, "amb@world_human_clipboard@male@idle_a", "idle_b", 8.0, -8.0, -1, 1, 0, false, false, false)

    if Config.Debug then print("[BANKING] Banker NPC gespawnt") end
end

-- ─── UI öffnen / schließen ────────────────────────────────────────────────────

local function OpenBanking(source)
    bankOpen = true
    SetNuiFocus(true, true)
    TriggerServerEvent("banking:open")
end

local function CloseBanking()
    bankOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = "close" })
end

-- ─── NUI Callbacks ───────────────────────────────────────────────────────────

RegisterNUICallback("closeBanking", function(_, cb)
    CloseBanking()
    cb({})
end)

RegisterNUICallback("deposit", function(data, cb)
    local amount = tonumber(data.amount) or 0
    if amount <= 0 then cb({ ok = false, error = "invalid" }); return end
    TriggerServerEvent("banking:deposit", amount)
    cb({ ok = true })
end)

RegisterNUICallback("withdraw", function(data, cb)
    local amount = tonumber(data.amount) or 0
    if amount <= 0 then cb({ ok = false, error = "invalid" }); return end
    TriggerServerEvent("banking:withdraw", amount)
    cb({ ok = true })
end)

-- ─── Server Antworten ────────────────────────────────────────────────────────

RegisterNetEvent("banking:receiveData", function(data)
    SendNUIMessage({
        type    = "open",
        cash    = data.cash,
        bank    = data.bank,
        history = data.history or {},
        locale  = Locales[ClientLang] or Locales['en'],
    })
end)

RegisterNetEvent("banking:result", function(result)
    SendNUIMessage({
        type    = "result",
        ok      = result.ok,
        cash    = result.cash,
        bank    = result.bank,
        message = result.message,
    })
end)

AddEventHandler("fivecore:languageChanged", function(lang)
    SendNUIMessage({ type = "setLang", locale = Locales[lang] or Locales['en'] })
end)

-- ─── Proximity Tick ──────────────────────────────────────────────────────────

CreateThread(function()
    -- Banker erst spawnen wenn Spieler aktiv im Netzwerk ist (auch nach Ressourcen-Neustart)
    while not NetworkIsPlayerActive(PlayerId()) do Wait(1000) end
    SpawnBanker()

    while true do
        Wait(0)
        if not NetworkIsPlayerActive(PlayerId()) then goto continue end

        local ped     = PlayerPedId()
        local pedPos  = GetEntityCoords(ped)

        -- Banker-Abstand
        local distNPC = #(pedPos - vector3(BANKER_COORDS.x, BANKER_COORDS.y, BANKER_COORDS.z))
        nearNPC = distNPC < INTERACT_DIST

        -- ATM-Abstand (spezifische Coords + benachbarte Props)
        local distATM = #(pedPos - vector3(ATM_COORDS.x, ATM_COORDS.y, ATM_COORDS.z))
        nearATM = distATM < INTERACT_DIST

        -- Auch benachbarte ATM-Props erkennen
        if not nearATM then
            for _, modelName in ipairs(ATM_MODELS) do
                local obj = GetClosestObjectOfType(pedPos.x, pedPos.y, pedPos.z, 1.5, GetHashKey(modelName), false, false, false)
                if obj ~= 0 then nearATM = true; break end
            end
        end

        -- Interaktionstext
        if nearNPC and not bankOpen then
            local locale = Locales[ClientLang] or Locales['en']
            local txt = (locale and locale['bank_npc_interact']) or "Press [E] to speak with banker"
            DrawText3D(BANKER_COORDS.x, BANKER_COORDS.y, BANKER_COORDS.z + 1.1, txt)
        end
        if nearATM and not bankOpen then
            local locale = Locales[ClientLang] or Locales['en']
            local txt = (locale and locale['bank_interact']) or "Press [E] to use ATM"
            DrawText3D(ATM_COORDS.x, ATM_COORDS.y, ATM_COORDS.z + 1.1, txt)
        end

        -- E-Taste
        if (nearNPC or nearATM) and not bankOpen then
            if IsControlJustReleased(0, 38) then -- E
                OpenBanking()
            end
        end

        ::continue::
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
