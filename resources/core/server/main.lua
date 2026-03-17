-- FiveCore Server Bootstrap

-- ─── Migrations ──────────────────────────────────────────────────────────────
-- SQL is embedded directly — no file I/O, works on all FiveM hosting platforms.

local MIGRATIONS = {
    -- 001: Core tables
    [[
        CREATE TABLE IF NOT EXISTS accounts (
            id         INT AUTO_INCREMENT PRIMARY KEY,
            identifier VARCHAR(100) UNIQUE NOT NULL,
            language   VARCHAR(5)  DEFAULT 'en',
            first_join DATETIME    DEFAULT CURRENT_TIMESTAMP,
            last_seen  DATETIME    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ]],
    [[
        CREATE TABLE IF NOT EXISTS characters (
            id         INT AUTO_INCREMENT PRIMARY KEY,
            account_id INT NOT NULL,
            slot       TINYINT     DEFAULT 1,
            firstname  VARCHAR(50),
            lastname   VARCHAR(50),
            dob        VARCHAR(20),
            gender     TINYINT     DEFAULT 0,
            appearance JSON,
            position   JSON,
            status     JSON,
            cash       INT         DEFAULT 500,
            bank       INT         DEFAULT 2000,
            job        JSON,
            licenses   JSON,
            phone      VARCHAR(20) UNIQUE,
            created_at DATETIME    DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
            INDEX idx_account (account_id)
        )
    ]],
    [[
        CREATE TABLE IF NOT EXISTS sms_messages (
            id         INT AUTO_INCREMENT PRIMARY KEY,
            from_phone VARCHAR(20),
            to_phone   VARCHAR(20),
            message    TEXT,
            sent_at    DATETIME DEFAULT CURRENT_TIMESTAMP,
            is_read    TINYINT  DEFAULT 0,
            INDEX idx_to_phone (to_phone)
        )
    ]],
    [[
        CREATE TABLE IF NOT EXISTS logs (
            id        INT AUTO_INCREMENT PRIMARY KEY,
            source    INT,
            action    VARCHAR(100),
            details   JSON,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_action (action)
        )
    ]],
    -- 002: Default status for existing characters
    [[
        UPDATE characters
        SET status = '{"hunger":100,"thirst":100,"stress":0}'
        WHERE status IS NULL
    ]],
    -- 003: Language column (safe to re-run)
    [[
        ALTER TABLE accounts
        ADD COLUMN IF NOT EXISTS language VARCHAR(5) DEFAULT 'en'
    ]],
}

local function RunMigrations()
    if not Config.Database.AutoMigrate then return end

    local ok_count = 0
    for i, stmt in ipairs(MIGRATIONS) do
        local ok, err = pcall(function()
            MySQL.query.await(stmt)
        end)
        if ok then
            ok_count = ok_count + 1
        elseif Config.Debug then
            print(("[CORE] Migration %d note: %s"):format(i, tostring(err)))
        end
    end

    print(("[CORE] Migrations done (%d/%d)."):format(ok_count, #MIGRATIONS))
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

-- ─── Client-Ready Event ───────────────────────────────────────────────────────
-- playerJoining fires before client Lua environments are fully initialized.
-- Instead, the client fires fivecore:clientReady once all its scripts have loaded.
-- This guarantees every RegisterNetEvent call has completed before we send anything.

RegisterNetEvent("fivecore:clientReady", function()
    local src = source
    -- Guard: ignore if already loaded (resource restart, double-fire)
    if Players[src] then return end
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

-- ─── Discord Webhook ─────────────────────────────────────────────────────────

local WEBHOOK_URL = GetConvar("fivecore_webhook", "")

local function SendDiscordWebhook(title, description, color, fields)
    if not WEBHOOK_URL or WEBHOOK_URL == "" then return end

    local payload = json.encode({
        embeds = {{
            title       = title,
            description = description,
            color       = color or 15158332,  -- rot
            fields      = fields or {},
            footer      = { text = "FiveCore Security" },
            timestamp   = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }}
    })

    PerformHttpRequest(WEBHOOK_URL, function(status)
        if Config.Debug then
            print("[WEBHOOK] Status: " .. tostring(status))
        end
    end, "POST", payload, { ["Content-Type"] = "application/json" })
end

-- ─── Admin Commands ─────────────────────────────────────────────────────────

-- Hilfsfunktion: Ziel-Spieler per Session-ID ODER FC-ID finden
local function ResolveTarget(arg)
    local num = tonumber(arg)
    if not num then return nil, nil end

    -- Direkte Session-ID prüfen
    if Players[num] then
        return num, Players[num]
    end

    -- FC-ID (account.id) suchen
    for src, p in pairs(Players) do
        if p.account and p.account.id == num then
            return src, p
        end
    end
    return nil, nil
end

-- /setjob [fc_id|session_id] [name] [grade] [label?]
-- ACE: command.setjob
RegisterCommand("setjob", function(source, args)
    local caller = source
    if caller ~= 0 then
        if not IsPlayerAceAllowed(tostring(caller), "command.setjob") then
            TriggerClientEvent(EVENTS.NOTIFY, caller, { text = "Keine Berechtigung.", type = NOTIFY_TYPES.ERROR })
            return
        end
    end

    local jobName = args[2]
    local grade   = tonumber(args[3]) or 0
    local label   = args[4] or jobName or "Unknown"

    if not args[1] or not jobName then
        local hint = "Nutzung: /setjob [fc_id|session_id] [job] [grade] [label]"
        if caller ~= 0 then TriggerClientEvent(EVENTS.NOTIFY, caller, { text = hint, type = NOTIFY_TYPES.INFO })
        else print("[CORE] " .. hint) end
        return
    end

    local targetId, p = ResolveTarget(args[1])
    if not targetId or not p or not p.character then
        local msg = "Spieler nicht gefunden (ID: " .. tostring(args[1]) .. "). Nutze FC-ID oder Session-ID."
        if caller ~= 0 then TriggerClientEvent(EVENTS.NOTIFY, caller, { text = msg, type = NOTIFY_TYPES.ERROR })
        else print("[CORE] " .. msg) end
        return
    end

    local job = { name = jobName, grade = grade, label = label }
    p.character.job = job
    DB.SaveJob(p.character.id, job)
    TriggerClientEvent("fivecore:jobUpdated", targetId, job)
    DB.Log(caller, "setjob_cmd", { fcId = p.account.id, target = targetId, job = jobName, grade = grade })

    local msg = string.format("Job gesetzt: %s → %s (Grade %d)", p.character.fullname, jobName, grade)
    if caller ~= 0 then TriggerClientEvent(EVENTS.NOTIFY, caller, { text = msg, type = NOTIFY_TYPES.SUCCESS })
    else print("[CORE] " .. msg) end
    TriggerClientEvent(EVENTS.NOTIFY, targetId, {
        text = string.format("Dein Job wurde geändert: %s (Grade %d)", label, grade),
        type = NOTIFY_TYPES.INFO,
    })
end, true)

-- /setgroup [fc_id|session_id] [group]
-- ACE: command.setgroup
RegisterCommand("setgroup", function(source, args)
    local caller = source
    if caller ~= 0 then
        if not IsPlayerAceAllowed(tostring(caller), "command.setgroup") then
            TriggerClientEvent(EVENTS.NOTIFY, caller, { text = "Keine Berechtigung.", type = NOTIFY_TYPES.ERROR })
            return
        end
    end

    local group = args[2]

    if not args[1] or not group then
        local hint = "Nutzung: /setgroup [fc_id|session_id] [group]"
        if caller ~= 0 then TriggerClientEvent(EVENTS.NOTIFY, caller, { text = hint, type = NOTIFY_TYPES.INFO })
        else print("[CORE] " .. hint) end
        return
    end

    local targetId, p = ResolveTarget(args[1])
    if not targetId or not p then
        local msg = "Spieler nicht gefunden (ID: " .. tostring(args[1]) .. ")."
        if caller ~= 0 then TriggerClientEvent(EVENTS.NOTIFY, caller, { text = msg, type = NOTIFY_TYPES.ERROR })
        else print("[CORE] " .. msg) end
        return
    end

    -- FiveM ACE-Gruppe zuweisen
    local identifier = GetPlayerIdentifierByType(targetId, "steam")
        or GetPlayerIdentifierByType(targetId, "license")
        or ("ip:" .. GetPlayerEndpoint(targetId))

    local aceIdent = identifier:gsub(":", ".")
    ExecuteCommand(string.format("add_principal identifier.%s group.%s", aceIdent, group))

    p.group = group
    DB.Log(caller, "setgroup_cmd", { fcId = p.account and p.account.id, target = targetId, group = group })

    local msg = string.format("Gruppe gesetzt: FC#%s → %s", tostring(p.account and p.account.id or targetId), group)
    if caller ~= 0 then TriggerClientEvent(EVENTS.NOTIFY, caller, { text = msg, type = NOTIFY_TYPES.SUCCESS })
    else print("[CORE] " .. msg) end
    TriggerClientEvent(EVENTS.NOTIFY, targetId, {
        text = string.format("Deine Gruppe wurde geändert: %s", group),
        type = NOTIFY_TYPES.INFO,
    })
end, true)

-- /job — Eigenen Job im Chat anzeigen (nur für dich sichtbar)
RegisterCommand("job", function(source, args)
    local src = source
    if src == 0 then return end

    local p = Players[src]
    if not p or not p.character then
        TriggerClientEvent(EVENTS.NOTIFY, src, { text = "Kein Charakter geladen.", type = NOTIFY_TYPES.INFO })
        return
    end

    local job   = p.character.job
    local name  = (job and job.name)  or "unemployed"
    local label = (job and job.label) or name
    local grade = (job and job.grade) or 0
    local fcId  = p.account and p.account.id or "?"

    TriggerClientEvent("chat:addMessage", src, {
        multiline = true,
        args = { "[FC#" .. fcId .. "] Job", string.format("%s (Grade %d) — %s", label, grade, name) },
        color = { 180, 160, 80 },
    })
end, false)

-- /group — Eigene Gruppe im Chat anzeigen (nur für dich sichtbar)
RegisterCommand("group", function(source, args)
    local src = source
    if src == 0 then return end

    local p = Players[src]
    if not p then
        TriggerClientEvent(EVENTS.NOTIFY, src, { text = "Nicht eingeloggt.", type = NOTIFY_TYPES.INFO })
        return
    end

    local fcId  = p.account and p.account.id or "?"
    local group = p.group or "none"

    -- ACE-Check: hat der Spieler bestimmte Gruppen?
    local aceGroups = {}
    for _, g in ipairs({ "admin", "superadmin", "moderator", "police", "ambulance" }) do
        if IsPlayerAceAllowed(tostring(src), "group." .. g) then
            table.insert(aceGroups, g)
        end
    end

    local aceTxt = #aceGroups > 0 and table.concat(aceGroups, ", ") or "none"

    TriggerClientEvent("chat:addMessage", src, {
        multiline = true,
        args = { "[FC#" .. fcId .. "] Gruppe", string.format("Cache: %s | ACE: %s", group, aceTxt) },
        color = { 80, 140, 200 },
    })
end, false)

-- ─── Sicherheit: Gruppen-Spoofing erkennen ────────────────────────────────────
-- Wenn ein Client-Event sensitive Aktionen fordert und Spieler keine Serverrolle hat

RegisterNetEvent("fivecore:reportGroupSpoof", function(data)
    -- Dieser Event wird NICHT vom Client ausgelöst, nur vom Server-internen Check
    -- Dummy-Schutz: ignorieren wenn von Client gesendet
end)

function FC_CheckGroupSecurity(src, claimedGroup)
    local p = Players[src]
    if not p then return false end

    local serverGroup = p.group or "none"
    local aceAllowed  = IsPlayerAceAllowed(tostring(src), "group." .. claimedGroup)

    -- Spieler hat keine Server-Bestätigung aber beansprucht die Gruppe
    if not aceAllowed and serverGroup ~= claimedGroup then
        local name  = GetPlayerName(src) or "Unknown"
        local fcId  = p.account and p.account.id or "?"
        local ident = GetPlayerIdentifierByType(src, "license") or GetPlayerIdentifierByType(src, "steam") or "unknown"

        -- Console log
        print(string.format("[SECURITY] GROUP SPOOF DETECTED: %s (FC#%s | %s) claimed group '%s' without server confirmation!",
            name, fcId, ident, claimedGroup))

        -- Discord Webhook
        SendDiscordWebhook(
            "Group Spoof Detected",
            string.format("Spieler **%s** hat Gruppe `%s` beansprucht ohne Server-Bestätigung.", name, claimedGroup),
            15158332,  -- rot
            {
                { name = "Spieler",     value = name,              inline = true  },
                { name = "FC-ID",       value = "FC#" .. tostring(fcId), inline = true },
                { name = "Session",     value = tostring(src),      inline = true  },
                { name = "Identifier",  value = ident,              inline = false },
                { name = "Beanspruchte Gruppe", value = claimedGroup, inline = true },
                { name = "Server-Gruppe", value = serverGroup,      inline = true  },
            }
        )

        DB.Log(src, "security_group_spoof", {
            claimed  = claimedGroup,
            server   = serverGroup,
            fcId     = fcId,
            ident    = ident,
        })

        return false
    end

    return true
end

-- ─── Update Checker ───────────────────────────────────────────────────────────

local FIVECORE_VERSION     = GetResourceMetadata(GetCurrentResourceName(), "version", 0) or "1.0.0"
local FIVECORE_UPDATE_URL  = "https://api.github.com/repos/FiveCore-Owner/FiveCore/releases/latest"

local function ParseVersion(str)
    -- strips a leading "v" and returns three numbers: major, minor, patch
    str = tostring(str):gsub("^v", "")
    local maj, min, pat = str:match("^(%d+)%.(%d+)%.(%d+)")
    return tonumber(maj) or 0, tonumber(min) or 0, tonumber(pat) or 0
end

local function IsNewerVersion(latest, current)
    local lMaj, lMin, lPat = ParseVersion(latest)
    local cMaj, cMin, cPat = ParseVersion(current)
    if lMaj ~= cMaj then return lMaj > cMaj end
    if lMin ~= cMin then return lMin > cMin end
    return lPat > cPat
end

local function CheckForUpdates()
    PerformHttpRequest(FIVECORE_UPDATE_URL, function(status, body, headers)
        if status ~= 200 or not body then
            if Config.Debug then
                print("[CORE] Update check failed — HTTP " .. tostring(status))
            end
            return
        end

        local ok, data = pcall(json.decode, body)
        if not ok or type(data) ~= "table" or not data.tag_name then
            if Config.Debug then print("[CORE] Update check failed — could not parse response") end
            return
        end

        local latestVersion = data.tag_name:gsub("^v", "")

        if IsNewerVersion(latestVersion, FIVECORE_VERSION) then
            print("╔══════════════════════════════════════════════════════╗")
            print("║           FiveCore — UPDATE AVAILABLE                ║")
            print(string.format("║  Current : %-41s ║", FIVECORE_VERSION))
            print(string.format("║  Latest  : %-41s ║", latestVersion))
            print("║  https://github.com/FiveCore-Owner/FiveCore/releases ║")
            print("╚══════════════════════════════════════════════════════╝")
        else
            print(string.format("[CORE] FiveCore v%s is up to date.", FIVECORE_VERSION))
        end
    end, "GET", "", { ["User-Agent"] = "FiveCore-UpdateChecker" })
end

-- ─── Start ────────────────────────────────────────────────────────────────────

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    print("[CORE] FiveCore Framework wird gestartet...")
    LoadLocaleConVars()
    RunMigrations()
    StartStatusTick()
    StartAutoSave()
    print("[CORE] FiveCore Framework bereit.")
    CheckForUpdates()
end)
