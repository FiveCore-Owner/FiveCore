-- FiveCore DB Layer
-- ALLE Datenbank-Queries sind hier zentralisiert.
-- Kein SQL in anderen Dateien oder Resources.

DB = {}

-- ─── Accounts ────────────────────────────────────────────────────────────────

function DB.GetAccount(identifier)
    return MySQL.single.await(
        "SELECT * FROM accounts WHERE identifier = ?",
        { identifier }
    )
end

function DB.CreateAccount(identifier)
    local id = MySQL.insert.await(
        "INSERT INTO accounts (identifier, language) VALUES (?, ?)",
        { identifier, DEFAULT_LANG }
    )
    return id
end

function DB.UpdateLastSeen(accountId)
    MySQL.update.await(
        "UPDATE accounts SET last_seen = NOW() WHERE id = ?",
        { accountId }
    )
end

function DB.SetLanguage(accountId, lang)
    MySQL.update.await(
        "UPDATE accounts SET language = ? WHERE id = ?",
        { lang, accountId }
    )
end

-- ─── Characters ──────────────────────────────────────────────────────────────

function DB.GetCharacters(accountId)
    return MySQL.query.await(
        "SELECT * FROM characters WHERE account_id = ? ORDER BY slot ASC",
        { accountId }
    )
end

function DB.GetCharacter(charId)
    return MySQL.single.await(
        "SELECT * FROM characters WHERE id = ?",
        { charId }
    )
end

function DB.CreateCharacter(accountId, data)
    local id = MySQL.insert.await([[
        INSERT INTO characters
            (account_id, slot, firstname, lastname, dob, gender, appearance,
             position, status, cash, bank, job, licenses, phone)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)
    ]], {
        accountId,
        data.slot,
        data.firstname,
        data.lastname,
        data.dob,
        data.gender,
        json.encode(data.appearance or {}),
        json.encode(data.position   or { x=195.0, y=-930.0, z=30.0, h=180.0 }),
        json.encode(data.status     or { hunger=100, thirst=100, stress=0 }),
        data.cash     or Config.StartCash,
        data.bank     or Config.StartBank,
        json.encode(data.job      or { name="unemployed", label="Arbeitslos", grade=0 }),
        json.encode(data.licenses or {}),
        data.phone,
    })
    return id
end

function DB.SaveCharacter(charId, data)
    MySQL.update.await([[
        UPDATE characters
        SET appearance = ?,
            position   = ?,
            status     = ?,
            cash       = ?,
            bank       = ?,
            job        = ?,
            licenses   = ?
        WHERE id = ?
    ]], {
        json.encode(data.appearance),
        json.encode(data.position),
        json.encode(data.status),
        data.cash,
        data.bank,
        json.encode(data.job),
        json.encode(data.licenses),
        charId,
    })
end

function DB.SaveJob(charId, job)
    MySQL.update.await(
        "UPDATE characters SET job = ? WHERE id = ?",
        { json.encode(job), charId }
    )
end

function DB.SavePosition(charId, position)
    MySQL.update.await(
        "UPDATE characters SET position = ? WHERE id = ?",
        { json.encode(position), charId }
    )
end

function DB.SaveStatus(charId, status)
    MySQL.update.await(
        "UPDATE characters SET status = ? WHERE id = ?",
        { json.encode(status), charId }
    )
end

function DB.UpdateMoney(charId, cash, bank)
    MySQL.update.await(
        "UPDATE characters SET cash = ?, bank = ? WHERE id = ?",
        { cash, bank, charId }
    )
end

function DB.DeleteCharacter(charId, accountId)
    MySQL.update.await(
        "DELETE FROM characters WHERE id = ? AND account_id = ?",
        { charId, accountId }
    )
end

function DB.CountCharacters(accountId)
    local result = MySQL.single.await(
        "SELECT COUNT(*) as cnt FROM characters WHERE account_id = ?",
        { accountId }
    )
    return result and result.cnt or 0
end

function DB.GetNextSlot(accountId)
    local result = MySQL.single.await(
        "SELECT IFNULL(MAX(slot),0)+1 as next_slot FROM characters WHERE account_id = ?",
        { accountId }
    )
    return result and result.next_slot or 1
end

-- ─── Phone ───────────────────────────────────────────────────────────────────

function DB.GetCharacterByPhone(phone)
    return MySQL.single.await(
        "SELECT * FROM characters WHERE phone = ?",
        { phone }
    )
end

function DB.PhoneExists(phone)
    local r = MySQL.single.await(
        "SELECT id FROM characters WHERE phone = ?",
        { phone }
    )
    return r ~= nil
end

-- ─── SMS ─────────────────────────────────────────────────────────────────────

function DB.SaveSMS(fromPhone, toPhone, message)
    MySQL.insert.await(
        "INSERT INTO sms_messages (from_phone, to_phone, message) VALUES (?,?,?)",
        { fromPhone, toPhone, message }
    )
end

function DB.GetSMS(phone, limit)
    return MySQL.query.await(
        "SELECT * FROM sms_messages WHERE to_phone = ? ORDER BY sent_at DESC LIMIT ?",
        { phone, limit or 50 }
    )
end

function DB.MarkSMSRead(phone)
    MySQL.update.await(
        "UPDATE sms_messages SET is_read = 1 WHERE to_phone = ?",
        { phone }
    )
end

-- ─── Logs ────────────────────────────────────────────────────────────────────

function DB.Log(source, action, details)
    MySQL.insert.await(
        "INSERT INTO logs (source, action, details) VALUES (?,?,?)",
        { source, action, json.encode(details or {}) }
    )
end
