-- FiveCore Banking — Server

local Core = nil
local function GetCore()
    if not Core then
        Core = exports['core']
    end
    return Core
end

-- ─── Banking öffnen ───────────────────────────────────────────────────────────

RegisterNetEvent("banking:open", function()
    local src = source
    if not FC_Security.RateLimit(src, "banking_open", 5, 10000) then return end

    local p = Players[src]
    if not p or not p.character then return end

    -- Transaktions-Historie (letzte 5 Log-Einträge für diesen Spieler)
    MySQL.query(
        "SELECT action, details, timestamp FROM logs WHERE source = ? AND action IN ('deposit','withdraw') ORDER BY timestamp DESC LIMIT 5",
        { src },
        function(rows)
            local history = {}
            for _, row in ipairs(rows or {}) do
                local details = row.details
                if type(details) == "string" then
                    details = json.decode(details) or {}
                end
                table.insert(history, {
                    action    = row.action,
                    amount    = details.amount or 0,
                    timestamp = tostring(row.timestamp),
                })
            end

            TriggerClientEvent("banking:receiveData", src, {
                cash    = p.character.cash or 0,
                bank    = p.character.bank or 0,
                history = history,
            })
        end
    )
end)

-- ─── Einzahlen ────────────────────────────────────────────────────────────────

RegisterNetEvent("banking:deposit", function(amount)
    local src = source
    if not FC_Security.RateLimit(src, "banking_tx", 10, 30000) then return end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or amount > 1000000 then
        TriggerClientEvent(EVENTS.NOTIFY, src, { text = T(src, 'bank_err_amount'), type = NOTIFY_TYPES.ERROR })
        return
    end

    local p = Players[src]
    if not p or not p.character then return end

    local cash = p.character.cash or 0
    if cash < amount then
        TriggerClientEvent(EVENTS.NOTIFY, src, { text = T(src, 'bank_err_no_cash'), type = NOTIFY_TYPES.ERROR })
        TriggerClientEvent("banking:result", src, { ok = false, message = T(src, 'bank_err_no_cash') })
        return
    end

    p.character.cash = cash - amount
    p.character.bank = (p.character.bank or 0) + amount

    DB.SaveMoney(p.character.id, p.character.cash, p.character.bank)
    DB.Log(src, "deposit", { amount = amount, cash = p.character.cash, bank = p.character.bank })

    TriggerClientEvent("fivecore:moneyUpdated", src, { cash = p.character.cash, bank = p.character.bank })
    TriggerClientEvent("banking:result", src, {
        ok      = true,
        cash    = p.character.cash,
        bank    = p.character.bank,
        message = string.format(T(src, 'bank_success_deposit'), amount),
    })
end)

-- ─── Abheben ─────────────────────────────────────────────────────────────────

RegisterNetEvent("banking:withdraw", function(amount)
    local src = source
    if not FC_Security.RateLimit(src, "banking_tx", 10, 30000) then return end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or amount > 1000000 then
        TriggerClientEvent(EVENTS.NOTIFY, src, { text = T(src, 'bank_err_amount'), type = NOTIFY_TYPES.ERROR })
        return
    end

    local p = Players[src]
    if not p or not p.character then return end

    local bank = p.character.bank or 0
    if bank < amount then
        TriggerClientEvent(EVENTS.NOTIFY, src, { text = T(src, 'bank_err_no_bank'), type = NOTIFY_TYPES.ERROR })
        TriggerClientEvent("banking:result", src, { ok = false, message = T(src, 'bank_err_no_bank') })
        return
    end

    p.character.bank = bank - amount
    p.character.cash = (p.character.cash or 0) + amount

    DB.SaveMoney(p.character.id, p.character.cash, p.character.bank)
    DB.Log(src, "withdraw", { amount = amount, cash = p.character.cash, bank = p.character.bank })

    TriggerClientEvent("fivecore:moneyUpdated", src, { cash = p.character.cash, bank = p.character.bank })
    TriggerClientEvent("banking:result", src, {
        ok      = true,
        cash    = p.character.cash,
        bank    = p.character.bank,
        message = string.format(T(src, 'bank_success_withdraw'), amount),
    })
end)
