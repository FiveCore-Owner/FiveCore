-- FiveCore — Server-side Event Registrations
-- All NetEvents go through security checks before touching game state.

-- ─── Character list ───────────────────────────────────────────────────────────

RegisterNetEvent(EVENTS.REQ_CHAR_LIST, function()
    local src = source
    if not FC_Security.RateLimit(src, "req_char_list", 5, 10000) then
        FC_Security.Warn(src, "REQ_CHAR_LIST rate limit exceeded")
        return
    end
    local list = FC_GetCharacterList(src)
    TriggerClientEvent("fivecore:receiveCharacterList", src, list)
end)

-- ─── Character creation ───────────────────────────────────────────────────────

RegisterNetEvent(EVENTS.CREATE_CHAR, function(data)
    local src = source
    if not FC_Security.RateLimit(src, "create_char", 3, 30000) then
        FC_Security.Warn(src, "CREATE_CHAR rate limit exceeded")
        return
    end
    if type(data) ~= "table" then
        FC_Security.Warn(src, "CREATE_CHAR invalid payload type")
        return
    end

    local ok, result = FC_CreateCharacter(src, data)
    if not ok then
        TriggerClientEvent(EVENTS.NOTIFY, src, { text = result, type = NOTIFY_TYPES.ERROR })
        TriggerClientEvent("fivecore:characterCreateResult", src, { success = false, error = result })
        return
    end

    FC_LoadCharacter(src, result)
    TriggerClientEvent("fivecore:characterCreateResult", src, { success = true, charId = result })
end)

-- ─── Character selection ──────────────────────────────────────────────────────

RegisterNetEvent(EVENTS.SELECT_CHAR, function(charId)
    local src = source
    if not FC_Security.RateLimit(src, "select_char", 5, 10000) then
        FC_Security.Warn(src, "SELECT_CHAR rate limit exceeded")
        return
    end
    charId = tonumber(charId)
    if not charId or charId <= 0 then
        FC_Security.Warn(src, "SELECT_CHAR invalid charId: " .. tostring(charId))
        return
    end

    local ok = FC_LoadCharacter(src, charId)
    if not ok then
        TriggerClientEvent(EVENTS.NOTIFY, src, {
            text = T(src, 'cc_load_error'),
            type = NOTIFY_TYPES.ERROR,
        })
    end
end)

-- ─── Character deletion ───────────────────────────────────────────────────────

RegisterNetEvent(EVENTS.DELETE_CHAR, function(charId)
    local src = source
    if not FC_Security.RateLimit(src, "delete_char", 3, 30000) then
        FC_Security.Warn(src, "DELETE_CHAR rate limit exceeded")
        return
    end
    charId = tonumber(charId)
    if not charId or charId <= 0 then
        FC_Security.Warn(src, "DELETE_CHAR invalid charId: " .. tostring(charId))
        return
    end

    local ok = FC_DeleteCharacter(src, charId)
    if ok then
        TriggerClientEvent(EVENTS.NOTIFY,     src, { text = T(src, 'cc_char_deleted'), type = NOTIFY_TYPES.SUCCESS })
        TriggerClientEvent(EVENTS.CHAR_DELETED, src, { charId = charId })
    end
end)

-- ─── Spawn request ────────────────────────────────────────────────────────────

RegisterNetEvent(EVENTS.REQ_SPAWN, function(spawnIndex)
    local src = source
    if not FC_Security.RateLimit(src, "req_spawn", 3, 10000) then
        FC_Security.Warn(src, "REQ_SPAWN rate limit exceeded")
        return
    end

    local p = Players[src]
    if not p or not p.character then return end

    spawnIndex = tonumber(spawnIndex)
    if not spawnIndex or spawnIndex < 1 or spawnIndex > #Config.Spawns then
        FC_Security.Warn(src, "REQ_SPAWN invalid spawnIndex: " .. tostring(spawnIndex))
        return
    end

    local spawn  = Config.Spawns[spawnIndex]
    local coords = spawn.coords
    if not coords then
        -- Last location
        local pos = p.character.position
        coords = vector4(pos.x, pos.y, pos.z, pos.h or 0.0)
    end

    p.state = CHARACTER_STATES.LOADED
    TriggerClientEvent("fivecore:doSpawn", src, { coords = coords })
    TriggerClientEvent(EVENTS.LOADING_STEP, src, LOADING_STEPS.DONE)

    DB.Log(src, "player_spawned", {
        name  = p.character.fullname,
        spawn = spawn.label,
    })
end)

-- ─── Status sync (client → server) ───────────────────────────────────────────
-- Players report their hunger/thirst/stress periodically.
-- We only accept values if the player is loaded and the numbers are sane.

RegisterNetEvent(EVENTS.SYNC_STATUS, function(status)
    local src = source
    if not FC_Security.RateLimit(src, "sync_status", 4, 60000) then return end

    local p = Players[src]
    if not p or not p.character then return end
    if type(status) ~= "table" then return end

    local function clamp(v)
        return math.max(0, math.min(100, math.floor(tonumber(v) or 100)))
    end

    -- Drift check: each tick drains at most Config.StatusDrain per call.
    -- If the client sends values much higher than what we last recorded,
    -- that is suspicious (cheater trying to prevent hunger/thirst drain).
    local cur = p.character.status
    local maxIncrease = (Config.StatusDrain or 5) * 3  -- allow a small buffer

    local newHunger = clamp(status.hunger)
    local newThirst = clamp(status.thirst)
    local newStress = clamp(status.stress)

    if newHunger > cur.hunger + maxIncrease then
        FC_Security.Warn(src, "SYNC_STATUS hunger spike", { old=cur.hunger, new=newHunger })
        newHunger = cur.hunger
    end
    if newThirst > cur.thirst + maxIncrease then
        FC_Security.Warn(src, "SYNC_STATUS thirst spike", { old=cur.thirst, new=newThirst })
        newThirst = cur.thirst
    end

    p.character.status = { hunger = newHunger, thirst = newThirst, stress = newStress }
    DB.SaveStatus(p.character.id, p.character.status)
end)

-- ─── Position save ────────────────────────────────────────────────────────────

RegisterNetEvent(EVENTS.SAVE_POSITION, function(position)
    local src = source
    if not FC_Security.RateLimit(src, "save_position", 2, 55000) then return end

    local p = Players[src]
    if not p or not p.character then return end
    if type(position) ~= "table" then return end

    local x = tonumber(position.x) or 0
    local y = tonumber(position.y) or 0
    local z = tonumber(position.z) or 0

    if not FC_Security.IsValidCoords(x, y, z) then
        FC_Security.Warn(src, "SAVE_POSITION out-of-bounds coords", { x=x, y=y, z=z })
        return
    end

    p.character.position = {
        x = x, y = y, z = z,
        h = tonumber(position.h) or 0,
    }
    DB.SavePosition(p.character.id, p.character.position)
end)

-- ─── Language change ──────────────────────────────────────────────────────────

RegisterNetEvent("fivecore:setPlayerLanguage", function(lang)
    local src = source
    if not FC_Security.RateLimit(src, "set_lang", 5, 30000) then return end

    local p = Players[src]
    if not p then return end

    lang = tostring(lang):lower():gsub("[^a-z]", ""):sub(1, 5)
    if not Locales[lang] then
        TriggerClientEvent(EVENTS.NOTIFY, src, {
            text = T(src, 'lang_invalid'),
            type = NOTIFY_TYPES.ERROR,
        })
        return
    end

    SetPlayerLang(src, lang)
    p.account.language = lang
    DB.SetLanguage(p.account.id, lang)
    TriggerClientEvent("fivecore:setLanguage", src, lang)
    TriggerClientEvent(EVENTS.NOTIFY, src, {
        text = T(src, 'lang_changed'),
        type = NOTIFY_TYPES.SUCCESS,
    })
end)
