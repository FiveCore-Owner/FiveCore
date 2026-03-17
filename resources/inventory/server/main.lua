-- FiveCore Inventory — Server

-- ─── Inventar laden (DB) ──────────────────────────────────────────────────────

local function LoadInventory(charId)
    local row = MySQL.single.await(
        "SELECT inventory FROM characters WHERE id = ?",
        { charId }
    )
    if not row or not row.inventory then
        return {}
    end
    local ok, inv = pcall(json.decode, row.inventory)
    return ok and type(inv) == "table" and inv or {}
end

local function SaveInventory(charId, inventory)
    MySQL.update.await(
        "UPDATE characters SET inventory = ? WHERE id = ?",
        { json.encode(inventory), charId }
    )
end

-- ─── Migration (inventory column) ────────────────────────────────────────────

AddEventHandler("onResourceStart", function(res)
    if res ~= GetCurrentResourceName() then return end
    local ok = pcall(function()
        MySQL.query.await("ALTER TABLE characters ADD COLUMN IF NOT EXISTS inventory JSON")
    end)
    if ok then print("[INVENTORY] DB-Migration done.") end
end)

-- ─── Client: Inventar anfordern ───────────────────────────────────────────────

RegisterNetEvent("inventory:open", function()
    local src = source
    local p   = exports.core:GetActiveCharacter(src)
    if not p then return end

    if not FC_Security.RateLimit(src, "inventory_open", 5, 10000) then return end

    local inv     = LoadInventory(p.id)
    local locale  = Locales and (Locales[ClientLang] or Locales['en']) or {}

    TriggerClientEvent("inventory:receiveInventory", src, {
        slots   = inv,
        charId  = p.id,
        locale  = locale,
    })
end)

-- ─── Item bewegen (drag & drop) ───────────────────────────────────────────────

RegisterNetEvent("inventory:moveItem", function(data)
    local src = source
    local p   = exports.core:GetActiveCharacter(src)
    if not p then return end

    if not FC_Security.RateLimit(src, "inventory_move", 20, 5000) then return end

    local fromSlot = tonumber(data.from)
    local toSlot   = tonumber(data.to)
    if not fromSlot or not toSlot then return end
    if fromSlot < 1 or fromSlot > 50 then return end  -- 45 + 5 hotbar = 50 max
    if toSlot   < 1 or toSlot   > 50 then return end

    local inv = LoadInventory(p.id)

    -- Tauschen oder bewegen
    local fromItem  = inv[tostring(fromSlot)]
    local toItem    = inv[tostring(toSlot)]
    inv[tostring(toSlot)]   = fromItem
    inv[tostring(fromSlot)] = toItem

    -- nil-Einträge aufräumen
    for k, v in pairs(inv) do
        if v == nil then inv[k] = nil end
    end

    SaveInventory(p.id, inv)

    TriggerClientEvent("inventory:receiveInventory", src, {
        slots  = inv,
        charId = p.id,
    })

    if Config.Debug then
        print(string.format("[INV] %d moved slot %d → %d", src, fromSlot, toSlot))
    end
end)

-- ─── Item benutzen ────────────────────────────────────────────────────────────

local USE_HANDLERS = {}

function RegisterItemUse(itemName, handler)
    USE_HANDLERS[itemName] = handler
end

RegisterNetEvent("inventory:useItem", function(data)
    local src  = source
    local p    = exports.core:GetActiveCharacter(src)
    if not p then return end

    if not FC_Security.RateLimit(src, "inventory_use", 5, 3000) then return end

    local slot  = tonumber(data.slot)
    if not slot or slot < 1 or slot > 50 then return end

    local inv   = LoadInventory(p.id)
    local item  = inv[tostring(slot)]
    if not item or not item.name then return end

    -- Item-Handler aufrufen
    local handler = USE_HANDLERS[item.name]
    if handler then
        local consumed = handler(src, item, slot)
        if consumed then
            -- Item verbrauchen (count -1)
            item.count = (item.count or 1) - 1
            if item.count <= 0 then
                inv[tostring(slot)] = nil
            else
                inv[tostring(slot)] = item
            end
            SaveInventory(p.id, inv)
            TriggerClientEvent("inventory:receiveInventory", src, { slots = inv, charId = p.id })
        end
    else
        if Config.Debug then print("[INV] Kein Handler für Item: " .. item.name) end
    end
end)

-- ─── Item hinzufügen (Export für andere Resources) ────────────────────────────

local function FindFreeSlot(inv, maxSlot)
    for i = 1, maxSlot do
        if not inv[tostring(i)] then return i end
    end
    return nil
end

exports("AddItem", function(src, itemName, count, data)
    local p = exports.core:GetActiveCharacter(src)
    if not p then return false end

    count = math.max(1, tonumber(count) or 1)
    local inv  = LoadInventory(p.id)
    local slot = FindFreeSlot(inv, 45)
    if not slot then
        TriggerClientEvent(EVENTS.NOTIFY, src, { text = "Inventar ist voll!", type = NOTIFY_TYPES.ERROR })
        return false
    end

    inv[tostring(slot)] = {
        name  = itemName,
        count = count,
        data  = data or {},
    }
    SaveInventory(p.id, inv)

    TriggerClientEvent("inventory:receiveInventory", src, { slots = inv, charId = p.id })
    return true
end)

exports("RemoveItem", function(src, itemName, count)
    local p = exports.core:GetActiveCharacter(src)
    if not p then return false end

    count = math.max(1, tonumber(count) or 1)
    local inv = LoadInventory(p.id)
    local removed = 0

    for slot, item in pairs(inv) do
        if item.name == itemName and removed < count then
            local take = math.min(item.count, count - removed)
            item.count = item.count - take
            removed    = removed + take
            if item.count <= 0 then
                inv[slot] = nil
            end
        end
    end

    if removed > 0 then
        SaveInventory(p.id, inv)
        TriggerClientEvent("inventory:receiveInventory", src, { slots = inv, charId = p.id })
        return true
    end
    return false
end)

exports("HasItem", function(src, itemName, count)
    local p = exports.core:GetActiveCharacter(src)
    if not p then return false end

    count    = tonumber(count) or 1
    local inv = LoadInventory(p.id)
    local total = 0
    for _, item in pairs(inv) do
        if item.name == itemName then
            total = total + (item.count or 1)
        end
    end
    return total >= count
end)
