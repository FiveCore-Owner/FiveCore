-- FiveCore Chat Server

local function GetCharName(source)
    local char = exports.core:GetActiveCharacter(source)
    if char then return char.fullname end
    return GetPlayerName(source) or ("Player " .. source)
end

-- ─── Lokaler Chat ─────────────────────────────────────────────────────────────

RegisterNetEvent("chat:sendLocal", function(message)
    local src  = source
    local name = GetCharName(src)
    local pos  = GetEntityCoords(GetPlayerPed(src))

    for _, pid in ipairs(GetPlayers()) do
        local ppos = GetEntityCoords(GetPlayerPed(tonumber(pid)))
        if #(pos - ppos) <= Config.LocalChatRadius then
            TriggerClientEvent("chat:addMessage", tonumber(pid), {
                type   = "local",
                sender = name,
                msg    = message,
            })
        end
    end

    MySQL.insert.await(
        "INSERT INTO logs (source, action, details) VALUES (?,?,?)",
        { src, "chat_local", json.encode({ name=name, msg=message }) }
    )
end)

-- ─── OOC ──────────────────────────────────────────────────────────────────────

RegisterNetEvent("chat:sendOOC", function(message)
    local src  = source
    local name = GetCharName(src)
    TriggerClientEvent("chat:addMessage", -1, {
        type   = "ooc",
        sender = name,
        msg    = message,
    })
end)

-- ─── /me ──────────────────────────────────────────────────────────────────────

RegisterNetEvent("chat:sendMe", function(message)
    local src  = source
    local name = GetCharName(src)
    local pos  = GetEntityCoords(GetPlayerPed(src))

    for _, pid in ipairs(GetPlayers()) do
        local ppos = GetEntityCoords(GetPlayerPed(tonumber(pid)))
        if #(pos - ppos) <= Config.MeChatRadius then
            TriggerClientEvent("chat:addMessage", tonumber(pid), {
                type   = "me",
                sender = name,
                msg    = message,
            })
        end
    end
end)

-- ─── System-Nachricht ────────────────────────────────────────────────────────

function ChatSystem(message, target)
    TriggerClientEvent("chat:addMessage", target or -1, {
        type = "system",
        msg  = message,
    })
end

-- ─── Broadcast ───────────────────────────────────────────────────────────────

RegisterNetEvent("chat:broadcast", function(message)
    local src = source
    if not IsPlayerAceAllowed(src, "command") then return end
    TriggerClientEvent("chat:addMessage", -1, {
        type = "broadcast",
        msg  = "📢 " .. message,
    })
end)

-- ─── Willkommensnachricht (lokalisiert) ──────────────────────────────────────

AddEventHandler("playerJoining", function()
    local src = source
    Wait(3000)
    TriggerClientEvent("chat:addMessage", src, {
        type = "system",
        msg  = T(src, 'chat_welcome'),
    })
end)

-- ─── /help (lokalisiert) ─────────────────────────────────────────────────────

RegisterCommand("help", function(source)
    local cmds = {
        T(source, 'chat_help_header'),
        T(source, 'chat_help_me'),
        T(source, 'chat_help_ooc'),
        T(source, 'chat_help_sms'),
        T(source, 'chat_help_lang'),
    }
    if Config.Debug then
        table.insert(cmds, T(source, 'chat_help_tp'))
        table.insert(cmds, T(source, 'chat_help_money'))
    end
    for _, line in ipairs(cmds) do
        TriggerClientEvent("chat:addMessage", source, { type = "system", msg = line })
    end
end, false)
