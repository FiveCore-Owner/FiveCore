-- FiveCore Text-Channel / Phone Client

local phoneOpen = false
local playerLoaded = false

-- ─── Spieler geladen → F2 aktivieren ─────────────────────────────────────────

AddEventHandler(EVENTS.PLAYER_LOADED, function()
    playerLoaded = true
end)

-- ─── F2 zum Öffnen/Schließen ─────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(0)
        if IsControlJustReleased(0, 289) then -- F2 = 289
            if playerLoaded then
                if phoneOpen then
                    ClosePhone()
                else
                    OpenPhone()
                end
            end
        end
    end
end)

-- ─── Phone öffnen ────────────────────────────────────────────────────────────

function OpenPhone()
    phoneOpen = true
    SetNuiFocus(true, true)
    TriggerServerEvent("phone:open")
end

function ClosePhone()
    phoneOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = "close" })
end

-- ─── Nachrichten vom Server ───────────────────────────────────────────────────

RegisterNetEvent("phone:receiveMessages", function(data)
    SendNUIMessage({
        type     = "open",
        myPhone  = data.myPhone,
        messages = data.messages,
        locale   = data.locale or Locales[ClientLang] or Locales['en'],
    })
end)

AddEventHandler("fivecore:languageChanged", function(lang)
    SendNUIMessage({ type = "setLang", locale = Locales[lang] or Locales['en'] })
end)

RegisterNetEvent("phone:receiveOutbox", function(msgs)
    SendNUIMessage({ type = "outbox", messages = msgs })
end)

RegisterNetEvent("phone:receiveSMS", function(data)
    -- Eingehende SMS während Spiel (Phone nicht geöffnet)
    SendNUIMessage({ type = "incoming", data = data })
end)

-- ─── NUI Callbacks ───────────────────────────────────────────────────────────

RegisterNUICallback("closePhone", function(_, cb)
    ClosePhone()
    cb({})
end)

RegisterNUICallback("getOutbox", function(_, cb)
    TriggerServerEvent("phone:getOutbox")
    cb({})
end)

RegisterNUICallback("sendSMS", function(data, cb)
    -- Direkt über Chatbefehl abwickeln
    if data.to and data.msg then
        TriggerServerEvent("sms", data.to, data.msg) -- geht über RegisterCommand
        -- Alternativ:
        ExecuteCommand(string.format("sms %s %s", data.to, data.msg))
    end
    cb({})
end)
