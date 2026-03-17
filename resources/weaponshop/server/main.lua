-- FiveCore Weapon Shop — Server

local LICENSE_PRICE   = 15000
local LICENSE_KEY     = "weapon_license"

-- ─── Waffenliste ─────────────────────────────────────────────────────────────

local WEAPONS = {
    { name = "WEAPON_PISTOL",       label = "Pistol",          price = 2500,  category = "handgun"  },
    { name = "WEAPON_COMBATPISTOL", label = "Combat Pistol",   price = 3500,  category = "handgun"  },
    { name = "WEAPON_APPISTOL",     label = "AP Pistol",       price = 4000,  category = "handgun"  },
    { name = "WEAPON_MICROSMG",     label = "Micro SMG",       price = 5000,  category = "smg"      },
    { name = "WEAPON_SMG",          label = "SMG",             price = 7500,  category = "smg"      },
    { name = "WEAPON_ASSAULTSMG",   label = "Assault SMG",     price = 9000,  category = "smg"      },
    { name = "WEAPON_PUMPSHOTGUN",  label = "Pump Shotgun",    price = 7000,  category = "shotgun"  },
    { name = "WEAPON_SAWNOFFSHOTGUN",label = "Sawn-Off",       price = 6000,  category = "shotgun"  },
    { name = "WEAPON_ASSAULTRIFLE", label = "Assault Rifle",   price = 15000, category = "rifle"    },
    { name = "WEAPON_CARBINERIFLE", label = "Carbine Rifle",   price = 12000, category = "rifle"    },
    { name = "WEAPON_KNIFE",        label = "Knife",           price = 500,   category = "melee"    },
    { name = "WEAPON_BAT",          label = "Baseball Bat",    price = 300,   category = "melee"    },
    { name = "WEAPON_CROWBAR",      label = "Crowbar",         price = 400,   category = "melee"    },
}

-- ─── Hilfsfunktionen ──────────────────────────────────────────────────────────

local function HasLicense(char)
    if not char or not char.licenses then return false end
    local lic = type(char.licenses) == "string" and json.decode(char.licenses) or char.licenses
    return lic and lic[LICENSE_KEY] == true
end

local function SetLicense(src, char)
    local lic = type(char.licenses) == "string" and json.decode(char.licenses) or char.licenses or {}
    lic[LICENSE_KEY] = true
    char.licenses = lic
    MySQL.update.await(
        "UPDATE characters SET licenses = ? WHERE id = ?",
        { json.encode(lic), char.id }
    )
    DB.Log(src, "weapon_license_bought", { charId = char.id })
end

-- ─── Shop öffnen (Client fordert Daten an) ───────────────────────────────────

RegisterNetEvent("weaponshop:open", function()
    local src = source
    local p   = exports.core:GetActiveCharacter(src)
    if not p then return end

    if not FC_Security.RateLimit(src, "weaponshop_open", 3, 5000) then return end

    local hasLic = HasLicense(p)

    TriggerClientEvent("weaponshop:receiveData", src, {
        hasLicense = hasLic,
        licensePrice = LICENSE_PRICE,
        weapons    = WEAPONS,
    })
end)

-- ─── Lizenz kaufen ───────────────────────────────────────────────────────────

RegisterNetEvent("weaponshop:buyLicense", function()
    local src = source
    local p   = exports.core:GetActiveCharacter(src)
    if not p then return end

    if not FC_Security.RateLimit(src, "weaponshop_buylicense", 1, 30000) then
        FC_Security.Warn(src, "weaponshop:buyLicense rate limit")
        return
    end

    if HasLicense(p) then
        TriggerClientEvent(EVENTS.NOTIFY, src, { text = "Du hast bereits eine Waffenlizenz.", type = NOTIFY_TYPES.INFO })
        return
    end

    -- Geld abziehen
    local ok = exports.core:RemoveMoney(src, LICENSE_PRICE, "weapon_license")
    if not ok then
        TriggerClientEvent(EVENTS.NOTIFY, src, { text = T(src, "notify_not_enough_money"), type = NOTIFY_TYPES.ERROR })
        TriggerClientEvent("weaponshop:result", src, { ok = false, error = "not_enough_money" })
        return
    end

    SetLicense(src, p)

    TriggerClientEvent(EVENTS.NOTIFY, src, {
        text = "Waffenlizenz erworben! Du kannst jetzt Waffen kaufen.",
        type = NOTIFY_TYPES.SUCCESS,
    })
    TriggerClientEvent("weaponshop:result", src, {
        ok         = true,
        action     = "license",
        hasLicense = true,
        cash       = p.cash,
    })
    DB.Log(src, "weapon_license_purchased", { price = LICENSE_PRICE })
end)

-- ─── Waffe kaufen ─────────────────────────────────────────────────────────────

RegisterNetEvent("weaponshop:buyWeapon", function(data)
    local src  = source
    local p    = exports.core:GetActiveCharacter(src)
    if not p then return end

    if not FC_Security.RateLimit(src, "weaponshop_buy", 5, 10000) then
        FC_Security.Warn(src, "weaponshop:buyWeapon rate limit")
        return
    end

    if not HasLicense(p) then
        FC_Security.Warn(src, "weaponshop:buyWeapon no license")
        TriggerClientEvent("weaponshop:result", src, { ok = false, error = "no_license" })
        return
    end

    -- Waffe validieren
    local weaponName = tostring(data.weapon or ""):upper()
    local weaponDef  = nil
    for _, w in ipairs(WEAPONS) do
        if w.name == weaponName then
            weaponDef = w
            break
        end
    end

    if not weaponDef then
        FC_Security.Warn(src, "weaponshop:buyWeapon invalid weapon: " .. weaponName)
        TriggerClientEvent("weaponshop:result", src, { ok = false, error = "invalid_weapon" })
        return
    end

    -- Geld abziehen
    local ok = exports.core:RemoveMoney(src, weaponDef.price, "weapon_purchase")
    if not ok then
        TriggerClientEvent(EVENTS.NOTIFY, src, { text = T(src, "notify_not_enough_money"), type = NOTIFY_TYPES.ERROR })
        TriggerClientEvent("weaponshop:result", src, { ok = false, error = "not_enough_money" })
        return
    end

    -- Waffe an Client übergeben (über Inventar-Export falls vorhanden)
    local hasInventory, _ = pcall(function()
        exports.inventory:AddItem(src, "weapon_" .. weaponDef.name:lower():gsub("weapon_", ""), 1, { weapon = weaponDef.name })
    end)

    -- Waffe direkt geben falls kein Inventar
    if not hasInventory then
        TriggerClientEvent("weaponshop:giveWeapon", src, weaponDef.name)
    end

    TriggerClientEvent(EVENTS.NOTIFY, src, {
        text = string.format("%s gekauft!", weaponDef.label),
        type = NOTIFY_TYPES.SUCCESS,
    })
    TriggerClientEvent("weaponshop:result", src, {
        ok      = true,
        action  = "weapon",
        weapon  = weaponDef.name,
        label   = weaponDef.label,
        cash    = p.cash,
    })

    DB.Log(src, "weapon_purchased", { weapon = weaponDef.name, price = weaponDef.price })
end)

-- ─── Training Range: Start anfordern ─────────────────────────────────────────

RegisterNetEvent("weaponshop:startTraining", function()
    local src = source
    local p   = exports.core:GetActiveCharacter(src)
    if not p then return end

    if not FC_Security.RateLimit(src, "training_start", 1, 60000) then return end

    TriggerClientEvent("weaponshop:beginTraining", src)
    DB.Log(src, "training_started", {})
end)

-- ─── Training Range: Abgeschlossen ───────────────────────────────────────────

RegisterNetEvent("weaponshop:trainingComplete", function(data)
    local src    = source
    local p      = exports.core:GetActiveCharacter(src)
    if not p then return end

    if not FC_Security.RateLimit(src, "training_complete", 1, 60000) then
        FC_Security.Warn(src, "weaponshop:trainingComplete rate limit")
        return
    end

    local kills = tonumber(data and data.kills) or 0

    -- Server-seitige Validierung: Mind. 10 Kills nötig
    if kills < 10 then
        TriggerClientEvent("weaponshop:trainingFailed", src)
        return
    end

    -- Erfolg: Pistole als Belohnung
    local hasInventory = pcall(function()
        exports.inventory:AddItem(src, "weapon_pistol", 1, { weapon = "WEAPON_PISTOL" })
    end)
    if not hasInventory then
        TriggerClientEvent("weaponshop:giveWeapon", src, "WEAPON_PISTOL")
    end

    TriggerClientEvent(EVENTS.NOTIFY, src, {
        text = "Training bestanden! Du hast eine Pistole erhalten.",
        type = NOTIFY_TYPES.SUCCESS,
    })
    TriggerClientEvent("weaponshop:trainingSuccess", src)
    DB.Log(src, "training_completed", { kills = kills })
end)
