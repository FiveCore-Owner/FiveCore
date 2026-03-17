-- FiveCore Player & Character State Machine
-- Alle Spieler-/Charakter-Daten liegen hier im Cache.
-- Andere Resources nutzen ausschließlich die exports.

Players = {}   -- Players[source] = { account, character, state }

-- ─── Interner Hilfsfunktionen ─────────────────────────────────────────────────

local function DecodeCharacter(row)
    if not row then return nil end
    return {
        id         = row.id,
        accountId  = row.account_id,
        slot       = row.slot,
        firstname  = row.firstname,
        lastname   = row.lastname,
        fullname   = row.firstname .. " " .. row.lastname,
        dob        = row.dob,
        gender     = row.gender,
        appearance = type(row.appearance) == "string" and json.decode(row.appearance) or row.appearance or {},
        position   = type(row.position)   == "string" and json.decode(row.position)   or row.position   or { x=195.0, y=-930.0, z=30.0, h=180.0 },
        status     = type(row.status)     == "string" and json.decode(row.status)     or row.status     or { hunger=100, thirst=100, stress=0 },
        cash       = row.cash  or Config.StartCash,
        bank       = row.bank  or Config.StartBank,
        job        = type(row.job)        == "string" and json.decode(row.job)        or row.job        or { name="unemployed", label="Arbeitslos", grade=0 },
        licenses   = type(row.licenses)   == "string" and json.decode(row.licenses)   or row.licenses   or {},
        phone      = row.phone,
    }
end

-- ─── Spieler laden (bei connect) ─────────────────────────────────────────────

function FC_LoadPlayer(source)
    local identifier = GetPlayerIdentifierByType(source, "steam")
        or GetPlayerIdentifierByType(source, "license")
        or ("ip:" .. GetPlayerEndpoint(source))

    TriggerClientEvent(EVENTS.LOADING_STEP, source, LOADING_STEPS.ACCOUNT)

    local account = DB.GetAccount(identifier)
    if not account then
        local newId = DB.CreateAccount(identifier)
        account = { id = newId, identifier = identifier }
        if Config.Debug then print("[CORE] Neuer Account erstellt: " .. identifier) end
    else
        DB.UpdateLastSeen(account.id)
    end

    -- Sprache laden und setzen
    local lang = account.language or DEFAULT_LANG
    if not Locales[lang] then lang = DEFAULT_LANG end
    SetPlayerLang(source, lang)

    Players[source] = {
        account   = account,
        character = nil,
        state     = CHARACTER_STATES.SELECTING,
    }

    -- Sprache + verfügbare Sprachen an Client senden
    TriggerClientEvent("fivecore:setLanguage", source, lang)
    TriggerClientEvent("fivecore:availableLanguages", source, {
        available = Config.AvailableLanguages,
        current   = lang,
        locales   = Locales,  -- alle Locale-Objekte mitschicken
    })

    if Config.Debug then print("[CORE] Spieler geladen: " .. source .. " → " .. identifier) end

    TriggerClientEvent(EVENTS.LOADING_STEP, source, LOADING_STEPS.CHAR_LIST)
    TriggerClientEvent("fivecore:showCharacterSelector", source)
end

-- ─── Charakter-Auswahl ────────────────────────────────────────────────────────

function FC_GetCharacterList(source)
    local p = Players[source]
    if not p then return {} end
    local rows = DB.GetCharacters(p.account.id)
    local list = {}
    for _, row in ipairs(rows) do
        table.insert(list, DecodeCharacter(row))
    end
    return list
end

function FC_LoadCharacter(source, charId)
    local p = Players[source]
    if not p then return false end

    local row = DB.GetCharacter(charId)
    if not row or row.account_id ~= p.account.id then
        if Config.Debug then print("[CORE] Charakter-Zugriff verweigert: " .. source) end
        return false
    end

    local char = DecodeCharacter(row)
    p.character = char
    p.state     = CHARACTER_STATES.SPAWNING

    TriggerClientEvent(EVENTS.LOADING_STEP, source, LOADING_STEPS.CHAR_SELECTED)
    TriggerClientEvent(EVENTS.PLAYER_LOADED, source, {
        character = char,
        money     = { cash = char.cash, bank = char.bank },
        position  = char.position,
    })

    DB.Log(source, "character_loaded", { charId = charId, name = char.fullname })
    if Config.Debug then print("[CORE] Charakter geladen: " .. char.fullname .. " für " .. source) end
    return true
end

function FC_CreateCharacter(source, data)
    local p = Players[source]
    if not p then return false, T(source, 'cc_not_connected') end

    -- Slot limit
    local count = DB.CountCharacters(p.account.id)
    if count >= Config.MaxCharacters then
        return false, T(source, 'cc_max_chars')
    end

    -- Name validation via security module
    if not FC_Security.IsValidName(data.firstname) then
        FC_Security.Warn(source, "CREATE_CHAR invalid firstname", { v = data.firstname })
        return false, T(source, 'cc_err_firstname')
    end
    if not FC_Security.IsValidName(data.lastname) then
        FC_Security.Warn(source, "CREATE_CHAR invalid lastname", { v = data.lastname })
        return false, T(source, 'cc_err_lastname')
    end

    -- Date of birth
    if not FC_Security.IsValidDOB(data.dob) then
        FC_Security.Warn(source, "CREATE_CHAR invalid dob", { v = data.dob })
        return false, T(source, 'cc_err_dob')
    end

    -- Gender
    if not FC_Security.IsValidGender(data.gender) then
        FC_Security.Warn(source, "CREATE_CHAR invalid gender", { v = data.gender })
        return false, T(source, 'cc_err_gender')
    end

    -- Sanitise appearance (clamp all values, strip unknown keys)
    local cleanAppearance = FC_Security.SanitiseAppearance(data.appearance)

    -- Generate phone and slot
    local phone = FC_GeneratePhone()
    local slot  = DB.GetNextSlot(p.account.id)

    local charId = DB.CreateCharacter(p.account.id, {
        slot       = slot,
        firstname  = data.firstname:sub(1, 50),
        lastname   = data.lastname:sub(1, 50),
        dob        = data.dob,
        gender     = data.gender,
        appearance = cleanAppearance,
        phone      = phone,
    })

    if not charId then return false, T(source, 'cc_db_error') end

    DB.Log(source, "character_created", {
        charId = charId,
        name   = data.firstname .. " " .. data.lastname,
    })

    return true, charId
end

function FC_DeleteCharacter(source, charId)
    local p = Players[source]
    if not p then return false end

    local row = DB.GetCharacter(charId)
    if not row or row.account_id ~= p.account.id then return false end

    DB.DeleteCharacter(charId, p.account.id)
    DB.Log(source, "character_deleted", { charId = charId })
    return true
end

-- ─── Telefon-Nummern-Generator ────────────────────────────────────────────────

function FC_GeneratePhone()
    local max_tries = 100
    for _ = 1, max_tries do
        local num = string.format("%s-%04d", Config.Phone.Prefix, math.random(0, 9999))
        if not DB.PhoneExists(num) then return num end
    end
    error("[CORE] Keine freie Telefonnummer gefunden!")
end

-- ─── Spieler trennt Verbindung ────────────────────────────────────────────────

function FC_UnloadPlayer(source)
    local p = Players[source]
    if not p then return end

    if p.character then
        DB.SaveCharacter(p.character.id, p.character)
        if Config.Debug then
            print("[CORE] Charakter gespeichert: " .. p.character.fullname)
        end
    end

    FC_Security.CleanPlayer(source)  -- release rate-limit buckets
    Players[source] = nil
end

-- ─── Exports (API für andere Resources) ──────────────────────────────────────

exports("GetAccount",        function(source)        return Players[source] and Players[source].account   end)
exports("GetActiveCharacter",function(source)        return Players[source] and Players[source].character  end)
exports("GetAllPlayers",     function()              return Players                                         end)
exports("GetCharacters",     function(accountId)     return DB.GetCharacters(accountId)                    end)
exports("GetPlayerByPhone",  function(phone)
    for src, p in pairs(Players) do
        if p.character and p.character.phone == phone then
            return src
        end
    end
    return nil
end)

exports("AddMoney", function(source, amount, reason)
    local p = Players[source]
    if not p or not p.character then return false end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end
    p.character.cash = p.character.cash + amount
    DB.UpdateMoney(p.character.id, p.character.cash, p.character.bank)
    DB.Log(source, "money_add", { amount=amount, reason=reason, newCash=p.character.cash })
    TriggerClientEvent(EVENTS.MONEY_UPDATED, source, { cash=p.character.cash, bank=p.character.bank })
    return p.character.cash
end)

exports("RemoveMoney", function(source, amount, reason)
    local p = Players[source]
    if not p or not p.character then return false end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or p.character.cash < amount then return false end
    p.character.cash = p.character.cash - amount
    DB.UpdateMoney(p.character.id, p.character.cash, p.character.bank)
    DB.Log(source, "money_remove", { amount=amount, reason=reason, newCash=p.character.cash })
    TriggerClientEvent(EVENTS.MONEY_UPDATED, source, { cash=p.character.cash, bank=p.character.bank })
    return p.character.cash
end)

exports("SetCharacterState", function(source, state)
    if Players[source] then Players[source].state = state end
end)

exports("GetCharacterState", function(source)
    return Players[source] and Players[source].state
end)
