-- FiveCore Inventory Client

local invOpen      = false
local hotbarVisible = true
local playerLoaded = false
local hotbarSlots  = {}   -- slots 46-50 = hotbar items (from server)

-- ─── Spieler geladen ──────────────────────────────────────────────────────────

AddEventHandler("fivecore:localPlayerSpawned", function()
    playerLoaded = true
    -- Inventar initial laden
    TriggerServerEvent("inventory:open")
end)

-- ─── Inventar öffnen (F2) ────────────────────────────────────────────────────

local function OpenInventory()
    invOpen = true
    SetNuiFocus(true, true)
    TriggerServerEvent("inventory:open")
end

local function CloseInventory()
    invOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = "close" })
end

-- ─── Hotbar anzeigen/verstecken ───────────────────────────────────────────────

local function ShowHotbar()
    hotbarVisible = true
    SendNUIMessage({ type = "hotbarShow" })
end

local function HideHotbar()
    hotbarVisible = false
    SendNUIMessage({ type = "hotbarHide" })
end

-- ─── NUI Callbacks ───────────────────────────────────────────────────────────

RegisterNUICallback("closeInventory", function(_, cb)
    CloseInventory()
    cb({})
end)

RegisterNUICallback("moveItem", function(data, cb)
    TriggerServerEvent("inventory:moveItem", data)
    cb({ ok = true })
end)

RegisterNUICallback("useItem", function(data, cb)
    TriggerServerEvent("inventory:useItem", data)
    cb({ ok = true })
end)

-- ─── Server → Client ─────────────────────────────────────────────────────────

RegisterNetEvent("inventory:receiveInventory", function(data)
    -- Hotbar-Slots aus Slots 46-50 extrahieren
    hotbarSlots = {}
    if data.slots then
        for i = 46, 50 do
            hotbarSlots[i - 45] = data.slots[tostring(i)]
        end
    end

    SendNUIMessage({
        type   = "inventory",
        slots  = data.slots  or {},
        isOpen = invOpen,
        locale = data.locale or Locales[ClientLang] or Locales['en'],
    })
end)

AddEventHandler("fivecore:languageChanged", function(lang)
    SendNUIMessage({ type = "setLang", locale = Locales[lang] or Locales['en'] })
end)

-- ─── Tasten-Thread ────────────────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(0)
        if not playerLoaded then goto iskip end

        -- F2 = Inventar öffnen (289)
        if IsControlJustReleased(0, 289) then
            if invOpen then
                CloseInventory()
            else
                OpenInventory()
            end
        end

        -- Waffenrad blockieren (INPUT_SELECT_WEAPON_UNARMED = 37)
        DisableControlAction(0, 37, true)   -- Waffen-Rad
        DisableControlAction(0, 157, true)  -- Nächste Waffe
        DisableControlAction(0, 158, true)  -- Vorherige Waffe
        DisableControlAction(0, 160, true)  -- Waffe auswählen

        -- Hotbar 1-5 Tasten (243-247 = Num1-Num5 / KEY_1-5)
        for key = 1, 5 do
            if IsControlJustReleased(0, 157 + key) then
                -- Hotbar-Slot aktivieren
                local item = hotbarSlots[key]
                if item and item.name then
                    TriggerServerEvent("inventory:useItem", { slot = 45 + key })
                end
            end
        end

        ::iskip::
    end
end)
