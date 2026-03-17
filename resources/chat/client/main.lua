-- FiveCore Chat Client

local isOpen    = false
local chatMode  = "local"

-- Sprache an Chat-NUI weitergeben
AddEventHandler("fivecore:languageChanged", function(lang)
    SendNUIMessage({ type = "setLang", locale = Locales[lang] or Locales['en'] })
end)

-- Bei Initialisierung Locale setzen
CreateThread(function()
    Wait(2000) -- warten bis core bereit
    SendNUIMessage({ type = "init", locale = Locales[ClientLang] or Locales['en'] })
end)

-- ─── Spieler-Status verfolgen ────────────────────────────────────────────────

local playerLoaded = false
AddEventHandler("fivecore:localPlayerSpawned", function()
    playerLoaded = true
end)

-- ─── Chat öffnen / schließen ─────────────────────────────────────────────────

local function OpenChat(mode)
    isOpen   = true
    chatMode = mode or "local"
    SetNuiFocus(true, false)  -- Tastatur, kein Maus-Focus
    SendNUIMessage({ type = "open", mode = chatMode })
end

local function CloseChat()
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = "close" })
end

-- ─── Tastenbelegung ──────────────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(0)
        -- T = lokalen Chat öffnen
        if IsControlJustReleased(0, 245) and not isOpen then -- T
            if playerLoaded then
                OpenChat("local")
            end
        end
    end
end)

-- ─── NUI Callbacks ───────────────────────────────────────────────────────────

RegisterNUICallback("sendMessage", function(data, cb)
    local msg  = tostring(data.message or ""):match("^%s*(.-)%s*$")
    local mode = data.mode or "local"

    if #msg == 0 then cb({}); return end

    -- Befehle erkennen
    if msg:sub(1,1) == "/" then
        local cmd  = msg:match("^/(%S+)")
        local rest = msg:match("^/%S+%s+(.+)") or ""

        if cmd == "me" then
            TriggerServerEvent("chat:sendMe", rest)
        elseif cmd == "ooc" then
            TriggerServerEvent("chat:sendOOC", rest)
        elseif cmd == "broadcast" then
            TriggerServerEvent("chat:broadcast", rest)
        else
            -- An FiveM-Befehlssystem weitergeben
            ExecuteCommand(msg:sub(2))
        end
    else
        -- Normaler Chat
        if mode == "ooc" then
            TriggerServerEvent("chat:sendOOC", msg)
        elseif mode == "me" then
            TriggerServerEvent("chat:sendMe", msg)
        else
            TriggerServerEvent("chat:sendLocal", msg)
        end
    end

    CloseChat()
    cb({})
end)

RegisterNUICallback("closeChat", function(_, cb)
    CloseChat()
    cb({})
end)

-- ─── Nachrichten empfangen ────────────────────────────────────────────────────

RegisterNetEvent("chat:addMessage", function(data)
    SendNUIMessage({
        type = "message",
        data = data,
    })
end)
