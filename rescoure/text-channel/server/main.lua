-- FiveCore Text-Channel / Phone Server

local rateLimits = {}

local function CheckRateLimit(source)
    local now = GetGameTimer()
    local rl  = rateLimits[source]
    if not rl or now > rl.resetAt then
        rateLimits[source] = { count = 1, resetAt = now + 60000 }
        return true
    end
    if rl.count >= Config.Phone.RateLimit then return false end
    rl.count = rl.count + 1
    return true
end

AddEventHandler("playerDropped", function()
    rateLimits[source] = nil
end)

-- ─── /sms Befehl (lokalisiert) ───────────────────────────────────────────────

RegisterCommand("sms", function(source, args)
    if #args < 2 then
        TriggerClientEvent(EVENTS.NOTIFY, source, { text = T(source, 'phone_usage'), type = NOTIFY_TYPES.INFO })
        return
    end

    local char = exports.core:GetActiveCharacter(source)
    if not char then
        TriggerClientEvent(EVENTS.NOTIFY, source, { text = T(source, 'phone_no_char'), type = NOTIFY_TYPES.ERROR })
        return
    end

    local toPhone = args[1]
    local message = table.concat(args, " ", 2)

    if #message > 200 then
        TriggerClientEvent(EVENTS.NOTIFY, source, { text = T(source, 'phone_msg_too_long'), type = NOTIFY_TYPES.WARNING })
        return
    end

    if not CheckRateLimit(source) then
        TriggerClientEvent(EVENTS.NOTIFY, source, { text = T(source, 'phone_rate_limit'), type = NOTIFY_TYPES.WARNING })
        return
    end

    if not toPhone:match("^%d%d%d%-%d%d%d%d$") and not toPhone:match("^%d+$") then
        TriggerClientEvent(EVENTS.NOTIFY, source, { text = T(source, 'phone_invalid_number'), type = NOTIFY_TYPES.ERROR })
        return
    end

    if toPhone == char.phone then
        TriggerClientEvent(EVENTS.NOTIFY, source, { text = T(source, 'phone_self_sms'), type = NOTIFY_TYPES.ERROR })
        return
    end

    local recipientRow = MySQL.single.await(
        "SELECT id, firstname, lastname FROM characters WHERE phone = ?",
        { toPhone }
    )
    if not recipientRow then
        TriggerClientEvent(EVENTS.NOTIFY, source, {
            text = T(source, 'phone_not_found', toPhone),
            type = NOTIFY_TYPES.ERROR,
        })
        return
    end

    MySQL.insert.await(
        "INSERT INTO sms_messages (from_phone, to_phone, message) VALUES (?,?,?)",
        { char.phone, toPhone, message }
    )

    TriggerClientEvent(EVENTS.NOTIFY, source, {
        text = T(source, 'phone_sent', toPhone),
        type = NOTIFY_TYPES.SUCCESS,
    })

    local recipientSrc = exports.core:GetPlayerByPhone(toPhone)
    if recipientSrc then
        TriggerClientEvent("phone:receiveSMS", recipientSrc, {
            from    = char.phone,
            message = message,
            time    = os.date("%H:%M"),
        })
        TriggerClientEvent(EVENTS.NOTIFY, recipientSrc, {
            text = T(recipientSrc, 'phone_incoming', char.phone, message),
            type = NOTIFY_TYPES.INFO,
        })
    end

    MySQL.insert.await(
        "INSERT INTO logs (source, action, details) VALUES (?,?,?)",
        { source, "sms_sent", json.encode({ from=char.phone, to=toPhone, len=#message }) }
    )
end, false)

-- ─── Telefon öffnen ──────────────────────────────────────────────────────────

RegisterNetEvent("phone:open", function()
    local src  = source
    local char = exports.core:GetActiveCharacter(src)
    if not char or not char.phone then return end

    local msgs = MySQL.query.await([[
        SELECT m.*, c.firstname, c.lastname
        FROM sms_messages m
        LEFT JOIN characters c ON c.phone = m.from_phone
        WHERE m.to_phone = ?
        ORDER BY m.sent_at DESC
        LIMIT 50
    ]], { char.phone })

    MySQL.update.await(
        "UPDATE sms_messages SET is_read = 1 WHERE to_phone = ?",
        { char.phone }
    )

    -- Locale für Phone-UI mitsenden
    local lang   = GetPlayerLang(src)
    local locale = Locales[lang] or Locales['en']

    TriggerClientEvent("phone:receiveMessages", src, {
        myPhone  = char.phone,
        messages = msgs or {},
        lang     = lang,
        locale   = locale,
    })
end)

-- ─── Outbox ──────────────────────────────────────────────────────────────────

RegisterNetEvent("phone:getOutbox", function()
    local src  = source
    local char = exports.core:GetActiveCharacter(src)
    if not char or not char.phone then return end

    local msgs = MySQL.query.await(
        "SELECT * FROM sms_messages WHERE from_phone = ? ORDER BY sent_at DESC LIMIT 30",
        { char.phone }
    )
    TriggerClientEvent("phone:receiveOutbox", src, msgs or {})
end)
