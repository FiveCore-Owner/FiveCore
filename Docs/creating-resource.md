# FiveCore — Creating New Resources

This guide explains exactly how to add a new resource to the server.
Every resource follows the same pattern — once you understand the structure once,
all others are identical.

---

## 1. Folder & File Structure

Every resource lives inside `resources/` and follows this layout:

```
resources/your-resource-name/
├── fxmanifest.lua          ← Required: tells FiveM about your resource
├── shared/
│   └── config.lua          ← Optional: resource-specific config values
├── server/
│   └── main.lua            ← Server-side logic
├── client/
│   └── main.lua            ← Client-side logic
└── ui/                     ← Optional: NUI (in-game browser)
    ├── index.html
    ├── style.css
    └── app.js
```

---

## 2. fxmanifest.lua — The Required File

This file tells FiveM what your resource contains.
**Always include the FiveCore shared scripts** so you have access to
`Config`, `EVENTS`, `T()`, `Locales`, and all constants.

```lua
fx_version 'cerulean'
game 'gta5'

author 'YourName'
description 'What this resource does'
version '1.0.0'

-- Always include these to get Config, EVENTS, T(), Locales, etc.
shared_scripts {
    '@core/shared/config.lua',
    '@core/shared/constants.lua',
    '@core/shared/locales.lua',
    '@core/locales/en.lua',
    '@core/locales/de.lua',
    '@core/locales/fr.lua',
    '@core/locales/zh.lua',
}

-- Server-only scripts (run on the server)
server_scripts {
    '@oxmysql/lib/MySQL.lua',   -- only if you need DB access
    'server/main.lua',
}

-- Client-only scripts (run in the player's game)
client_scripts {
    'client/main.lua',
}

-- If you have a NUI (in-game webpage):
ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/app.js',
}
```

---

## 3. Add to server.cfg

Open `server.cfg` and add your resource to the load order.
**Order matters** — resources that depend on `core` must come after it.

```cfg
ensure oxmysql
ensure core
ensure loading-screen
ensure character-creator
ensure spawn-selector
ensure hud
ensure text-channel
ensure chat
ensure your-resource-name    ← ADD HERE
```

---

## 4. Server Script Pattern

`server/main.lua` — runs on the server.

```lua
-- server/main.lua

-- ─── Listen for a client event ───────────────────────────────────────────────

RegisterNetEvent("yourresource:doSomething", function(data)
    local src = source  -- ALWAYS read source immediately — it's a global

    -- Always verify the player is logged in and has a character
    local char = exports.core:GetActiveCharacter(src)
    if not char then return end

    -- Validate data from the client — NEVER trust client values
    if type(data) ~= "table" then return end
    if not data.value or type(data.value) ~= "number" then return end
    if data.value < 0 or data.value > 1000 then return end  -- range check

    -- Do your logic here
    print("[YOURRESOURCE] " .. char.fullname .. " did something: " .. data.value)

    -- Send a response back to the client
    TriggerClientEvent("yourresource:result", src, { success = true })

    -- Send a notification (translated)
    TriggerClientEvent(EVENTS.NOTIFY, src, {
        text = T(src, 'some_locale_key'),
        type = NOTIFY_TYPES.SUCCESS,
    })

    -- Log the action
    MySQL.insert.await(
        "INSERT INTO logs (source, action, details) VALUES (?,?,?)",
        { src, "yourresource_action", json.encode({ charId = char.id, value = data.value }) }
    )
end)

-- ─── Register a command ──────────────────────────────────────────────────────

RegisterCommand("yourcommand", function(source, args)
    local char = exports.core:GetActiveCharacter(source)
    if not char then
        TriggerClientEvent(EVENTS.NOTIFY, source, {
            text = T(source, 'not_connected'),
            type = NOTIFY_TYPES.ERROR,
        })
        return
    end

    -- args[1], args[2], ... are the command arguments (strings)
    local value = tonumber(args[1])
    if not value then return end

    -- Your logic here
end, false)   -- false = available to all players, true = restricted

-- ─── Export a function for other resources ───────────────────────────────────

exports("GetSomeData", function(source)
    local char = exports.core:GetActiveCharacter(source)
    if not char then return nil end
    return { charId = char.id, phone = char.phone }
end)
```

---

## 5. Client Script Pattern

`client/main.lua` — runs in the player's game client.

```lua
-- client/main.lua

local isOpen = false

-- ─── React to character being loaded ─────────────────────────────────────────

AddEventHandler(EVENTS.PLAYER_LOADED, function(data)
    -- data = { character, money, position }
    -- Called when the player's character finishes loading
    -- Safe to show UI, start threads, etc.
    print("[YOURRESOURCE] Character loaded: " .. data.character.fullname)
end)

-- ─── Listen for a server event ───────────────────────────────────────────────

RegisterNetEvent("yourresource:result", function(data)
    if data.success then
        FC_Notify("It worked!", NOTIFY_TYPES.SUCCESS)
    end
end)

-- ─── Send an event to the server ─────────────────────────────────────────────

RegisterCommand("testcmd", function(source, args)
    TriggerServerEvent("yourresource:doSomething", { value = 42 })
end, false)

-- ─── Key binding ─────────────────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(0)
        -- F3 = control index 182
        if IsControlJustReleased(0, 182) then
            if LocalPlayer.loaded then
                OpenMyUI()
            end
        end
    end
end)

-- ─── Open NUI ────────────────────────────────────────────────────────────────

function OpenMyUI()
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        type   = "open",
        locale = Locales[ClientLang] or Locales['en'],
    })
end

function CloseMyUI()
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = "close" })
end

-- ─── NUI Callbacks (NUI → Lua) ────────────────────────────────────────────────

RegisterNUICallback("closeUI", function(data, cb)
    CloseMyUI()
    cb({ ok = true })
end)

RegisterNUICallback("submitForm", function(data, cb)
    TriggerServerEvent("yourresource:doSomething", data)
    cb({ ok = true })
end)

-- ─── Language change support ─────────────────────────────────────────────────

AddEventHandler("fivecore:languageChanged", function(lang)
    SendNUIMessage({ type = "setLang", locale = Locales[lang] or Locales['en'] })
end)
```

---

## 6. NUI (UI) Pattern

### `ui/index.html`

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>My Resource</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
<div id="app" style="display:none">

    <!-- Use data-i18n="locale_key" for translated text -->
    <div class="title" data-i18n="my_resource_title">My Resource</div>

    <!-- Use data-i18n-placeholder for input placeholders -->
    <input type="text" id="my-input"
           data-i18n-placeholder="my_resource_input_placeholder"
           placeholder="Enter something...">

    <button id="btn-submit" data-i18n="my_resource_submit">Submit</button>
    <button id="btn-close"  data-i18n="my_resource_close">Close</button>
</div>
<script src="app.js"></script>
</body>
</html>
```

### `ui/app.js`

```javascript
'use strict';

// ─── i18n (copy this block into every NUI) ───────────────────────────────────
let _locale = {};
function t(key, ...args) {
    let str = _locale[key] ?? key;
    if (args.length > 0) { let i = 0; str = str.replace(/%[sd]/g, () => String(args[i++] ?? '')); }
    return str;
}
function applyI18n() {
    document.querySelectorAll('[data-i18n]').forEach(el => el.textContent = t(el.dataset.i18n));
    document.querySelectorAll('[data-i18n-placeholder]').forEach(el => el.placeholder = t(el.dataset.i18nPlaceholder));
}

// ─── Post to Lua ──────────────────────────────────────────────────────────────
function post(cb, data) {
    return fetch(`https://${GetParentResourceName()}/${cb}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
    }).then(r => r.json()).catch(() => {});
}

// ─── Button handlers ──────────────────────────────────────────────────────────
document.getElementById('btn-submit').addEventListener('click', () => {
    const value = document.getElementById('my-input').value.trim();
    if (!value) return;
    post('submitForm', { value });
});

document.getElementById('btn-close').addEventListener('click', () => {
    post('closeUI', {});
});

// ─── NUI Message handler ──────────────────────────────────────────────────────
window.addEventListener('message', e => {
    const data = e.data;
    if (!data || !data.type) return;

    if (data.type === 'open') {
        if (data.locale) { _locale = data.locale; applyI18n(); }
        document.getElementById('app').style.display = 'block';
    }
    if (data.type === 'close') {
        document.getElementById('app').style.display = 'none';
    }
    if (data.type === 'setLang') {
        if (data.locale) { _locale = data.locale; applyI18n(); }
    }
});
```

---

## 7. Adding Translations for Your Resource

Open each locale file in `core/locales/` and add your new keys:

### `core/locales/en.lua`
```lua
-- Add to the bottom (or in a clearly labelled section)
-- ─── My Resource ──────────────────────────────────────────────────────────────
['my_resource_title']             = "My Resource",
['my_resource_input_placeholder'] = "Enter something...",
['my_resource_submit']            = "Submit",
['my_resource_close']             = "Close",
['my_resource_success']           = "Action successful!",
['my_resource_error']             = "Something went wrong.",
```

### `core/locales/de.lua`
```lua
['my_resource_title']             = "Meine Resource",
['my_resource_input_placeholder'] = "Etwas eingeben...",
['my_resource_submit']            = "Absenden",
['my_resource_close']             = "Schließen",
['my_resource_success']           = "Aktion erfolgreich!",
['my_resource_error']             = "Etwas ist schiefgelaufen.",
```

*(Repeat for `fr.lua` and `zh.lua`)*

---

## 8. Using the Database

**All SQL must go in a `db.lua` file inside your resource.** No SQL strings in `main.lua`.

```lua
-- server/db.lua

YourResourceDB = {}

function YourResourceDB.GetSomething(charId)
    return MySQL.single.await(
        "SELECT * FROM your_table WHERE char_id = ?",
        { charId }
    )
end

function YourResourceDB.SaveSomething(charId, value)
    MySQL.update.await(
        "UPDATE your_table SET value = ? WHERE char_id = ?",
        { value, charId }
    )
end
```

Add a migration file for your table:

```sql
-- database/migrations/004_my_resource.sql

CREATE TABLE IF NOT EXISTS your_table (
    id       INT AUTO_INCREMENT PRIMARY KEY,
    char_id  INT NOT NULL,
    value    VARCHAR(255),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (char_id) REFERENCES characters(id) ON DELETE CASCADE,
    INDEX idx_char (char_id)
);
```

---

## 9. Complete Real-World Example: `/me` Status Board

A resource that tracks what a player is doing (e.g. "eating", "working") and
broadcasts it to nearby players.

**`resources/status-board/fxmanifest.lua`**
```lua
fx_version 'cerulean'
game 'gta5'

shared_scripts {
    '@core/shared/config.lua',
    '@core/shared/constants.lua',
    '@core/shared/locales.lua',
    '@core/locales/en.lua',
    '@core/locales/de.lua',
    '@core/locales/fr.lua',
    '@core/locales/zh.lua',
}
server_scripts { 'server/main.lua' }
client_scripts { 'client/main.lua' }
```

**`resources/status-board/server/main.lua`**
```lua
RegisterCommand("status", function(source, args)
    local char = exports.core:GetActiveCharacter(source)
    if not char then return end

    local status = table.concat(args, " ")
    if #status > 50 then
        TriggerClientEvent(EVENTS.NOTIFY, source, {
            text = "Status too long (max 50 chars).",
            type = NOTIFY_TYPES.ERROR,
        })
        return
    end

    -- Broadcast to nearby players
    local pos = GetEntityCoords(GetPlayerPed(source))
    for _, pid in ipairs(GetPlayers()) do
        local ppos = GetEntityCoords(GetPlayerPed(tonumber(pid)))
        if #(pos - ppos) <= 20.0 then
            TriggerClientEvent("statusboard:show", tonumber(pid), {
                name   = char.fullname,
                status = status,
            })
        end
    end
end, false)
```

**`resources/status-board/client/main.lua`**
```lua
RegisterNetEvent("statusboard:show", function(data)
    FC_Notify(data.name .. ": " .. data.status, NOTIFY_TYPES.INFO, 5000)
end)
```

Add to `server.cfg`:
```cfg
ensure status-board
```

Done. 10 lines of code, fully integrated into the framework.

---

## 10. Checklist Before Adding a Resource

- [ ] `fxmanifest.lua` includes all 4 locale files from `@core/locales/`
- [ ] Resource is added to `server.cfg` in the correct position
- [ ] All client input is validated server-side
- [ ] No hardcoded money/stat changes — use `exports.core:AddMoney()` etc.
- [ ] Translation keys added to all 4 locale files (`en`, `de`, `fr`, `zh`)
- [ ] NUI sends/receives `setLang` for live language switching
- [ ] Database queries are in a separate `db.lua`
- [ ] Any new DB tables have a migration file in `database/migrations/`
- [ ] Actions are logged to the `logs` table
