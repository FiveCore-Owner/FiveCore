-- FiveCore Server Bootstrap

-- ─── Migrations ──────────────────────────────────────────────────────────────

local function RunMigrations()
    if not Config.Database.AutoMigrate then return end

    local migrationFiles = {
        GetResourcePath(GetCurrentResourceName()) .. "/../../database/migrations/001_init.sql",
        GetResourcePath(GetCurrentResourceName()) .. "/../../database/migrations/002_status.sql",
    }

    for _, path in ipairs(migrationFiles) do
        local f = io.open(path, "r")
        if f then
            local sql = f:read("*a")
            f:close()
            -- Statements aufteilen und einzeln ausführen
            for stmt in sql:gmatch("([^;]+);") do
                stmt = stmt:match("^%s*(.-)%s*$")
                if #stmt > 5 then
                    local ok, err = pcall(function()
                        MySQL.query.await(stmt)
                    end)
                    if not ok and Config.Debug then
                        print("[CORE] Migration-Hinweis: " .. tostring(err))
                    end
                end
            end
            if Config.Debug then print("[CORE] Migration ausgeführt: " .. path) end
        else
            if Config.Debug then print("[CORE] Migration-Datei nicht gefunden: " .. path) end
        end
    end
end

-- ─── Status-Tick (Hunger/Durst) ───────────────────────────────────────────────

local function StartStatusTick()
    CreateThread(function()
        while true do
            Wait(Config.StatusTickInterval)
            for src, p in pairs(Players) do
                if p.character and p.state == CHARACTER_STATES.LOADED then
                    local s = p.character.status
                    s.hunger = math.max(0, s.hunger - Config.StatusDrain.hunger)
                    s.thirst = math.max(0, s.thirst - Config.StatusDrain.thirst)
                    p.character.status = s
                    TriggerClientEvent(EVENTS.STATUS_UPDATED, src, s)
                    DB.SaveStatus(p.character.id, s)
                end
            end
        end
    end)
end

-- ─── Auto-Save ────────────────────────────────────────────────────────────────

local function StartAutoSave()
    CreateThread(function()
        while true do
            Wait(Config.AutoSaveInterval)
            local saved = 0
            for src, p in pairs(Players) do
                if p.character then
                    DB.SaveCharacter(p.character.id, p.character)
                    saved = saved + 1
                end
            end
            if Config.Debug and saved > 0 then
                print(string.format("[CORE] Auto-Save: %d Charakter(e) gespeichert", saved))
            end
        end
    end)
end

-- ─── Player Connect / Disconnect ─────────────────────────────────────────────

AddEventHandler("playerConnecting", function(name, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    deferrals.update("Verbinde mit FiveCore...")
    Wait(200)
    deferrals.done()
end)

AddEventHandler("playerDropped", function(reason)
    local src = source
    FC_UnloadPlayer(src)
    if Config.Debug then
        print(string.format("[CORE] Spieler getrennt: %s (%s)", src, reason))
    end
end)

-- Spieler-spawn (FiveM-intern) → Account laden
AddEventHandler("playerJoining", function()
    local src = source
    FC_LoadPlayer(src)
end)

-- ─── Debug-Befehle (nur wenn Config.Debug = true) ────────────────────────────

-- ─── ConVar: Verfügbare Sprachen laden ───────────────────────────────────────

local function LoadLocaleConVars()
    -- set fivecore_locales "de,en,fr,zh"
    local raw      = GetConvar("fivecore_locales", "en")
    local defaultL = GetConvar("fivecore_default_lang", "en"):lower():gsub("[^a-z]","")

    Config.AvailableLanguages = {}
    for lang in raw:gmatch("[^,]+") do
        lang = lang:lower():gsub("[^a-z]","")
        if Locales[lang] then
            table.insert(Config.AvailableLanguages, lang)
        end
    end
    if #Config.AvailableLanguages == 0 then
        Config.AvailableLanguages = { "en" }
    end

    if Locales[defaultL] then
        Config.DefaultLang = defaultL
        DEFAULT_LANG       = defaultL
    end

    print(string.format("[CORE] Sprachen: %s | Standard: %s",
        table.concat(Config.AvailableLanguages, ", "), Config.DefaultLang))
end

-- ─── Migrations-Erweiterung ───────────────────────────────────────────────────

local function RunMigration003()
    pcall(function()
        MySQL.query.await(
            "ALTER TABLE accounts ADD COLUMN IF NOT EXISTS language VARCHAR(5) DEFAULT 'en'"
        )
    end)
end

if Config.Debug then
    RegisterCommand("tp", function(source, args)
        if #args < 3 then
            TriggerClientEvent(EVENTS.NOTIFY, source, { text = "Nutzung: /tp x y z", type = NOTIFY_TYPES.INFO })
            return
        end
        TriggerClientEvent("fivecore:debugTeleport", source, {
            x = tonumber(args[1]) or 0,
            y = tonumber(args[2]) or 0,
            z = tonumber(args[3]) or 0,
        })
    end, false)

    RegisterCommand("addmoney", function(source, args)
        local amount = tonumber(args[1]) or 0
        if amount <= 0 then return end
        exports.core:AddMoney(source, amount, "debug")
        TriggerClientEvent(EVENTS.NOTIFY, source, {
            text = string.format("$%d hinzugefügt (Debug)", amount),
            type = NOTIFY_TYPES.SUCCESS,
        })
    end, false)

    RegisterCommand("myid", function(source)
        print("[DEBUG] Source: " .. source)
        local p = Players[source]
        if p and p.character then
            print("[DEBUG] Char: " .. p.character.fullname .. " | Phone: " .. tostring(p.character.phone))
        end
    end, false)
end

-- ─── Start ────────────────────────────────────────────────────────────────────

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    print("[CORE] FiveCore Framework wird gestartet...")
    LoadLocaleConVars()
    RunMigrations()
    RunMigration003()
    StartStatusTick()
    StartAutoSave()
    print("[CORE] FiveCore Framework bereit.")
end)
