# FiveCore Roleplay — Complete Project Overview

> Custom FiveM framework built from scratch. No ESX. No QBCore. Fully owned.

---

## What We Built

### Server Stack

| Layer | Technology |
|---|---|
| Game Server | FiveM (CitizenFX) |
| Database | MySQL via oxmysql |
| Server Scripts | Lua 5.4 |
| Client Scripts | Lua 5.4 |
| UI (NUI) | HTML5 + CSS3 + Vanilla JS |
| Languages | English, Deutsch, Français, 中文 |

---

## File Structure

```
server/
├── server.cfg                    ← Live server config (credentials)
├── fivecoretemplate.cfg          ← Template for clean installs
├── database/
│   └── migrations/
│       ├── 001_init.sql          ← Core tables (accounts, characters, sms, logs)
│       ├── 002_status.sql        ← Default status values
│       └── 003_language.sql      ← Language preference column
├── docs/                         ← You are here
└── resources/
    ├── [system]/oxmysql/         ← Database connector (download separately)
    ├── core/                     ← FiveCore Framework
    ├── loading-screen/           ← Connection loading screen
    ├── character-creator/        ← Character selection + creation
    ├── spawn-selector/           ← Spawn point picker
    ├── hud/                      ← In-game HUD
    ├── text-channel/             ← Phone + SMS system
    └── chat/                     ← Custom chat system
```

---

## Resources — What Each One Does

### `core` — The Framework
The foundation everything else is built on. Must load first.

**Server-side:**
- Reads database credentials and boots migrations on start
- Reads `fivecore_locales` and `fivecore_default_lang` from `server.cfg`
- Creates/looks up player accounts on connect (by Steam/license identifier)
- Manages the character state machine per player:
  `idle → selecting → creating → spawning → loaded`
- Provides all server-side exports other resources call
- Ticks hunger/thirst/stress every 30 seconds
- Auto-saves all loaded characters every 5 minutes
- Logs all money changes, spawns, and chat to the `logs` table
- Cleans up player data on disconnect

**Client-side:**
- Holds `LocalPlayer` state (character, money, status)
- Receives and applies language from server
- Saves position to server every 60 seconds
- Syncs status (hunger/thirst) back to server periodically
- Provides `FC_Notify()`, `FC_DrawText3D()`, `FC_ShowHelpText()` utilities

**Shared (both sides):**
- `Config` — all configuration values
- `EVENTS` — all event name constants
- `CHARACTER_STATES`, `NOTIFY_TYPES` — enums
- `T(source?, 'key')` — translation function
- All 4 locale tables

---

### `loading-screen` — Connection Screen
Shown while the game assets download and the player connects.

- Animated progress bar that reacts to FiveM's native `loadFraction`
- 6-step visual indicator: Server → Account → Character → Spawn → World → Ready
- Rotating tips (7 tips, translated into all 4 languages)
- Floating particle background effect
- Receives `loading:updateStep` events from `core` to advance steps
- Inline EN fallback so it works before the server sends a language

---

### `character-creator` — Character System
Shown immediately after connecting, before spawning in the world.

**Language Selection (first connect):**
- If `fivecore_locales` has more than one language, a flag picker is shown first
- Selection is saved to the database; shown immediately on every subsequent login

**Character Selection:**
- Lists all characters for this account (max. 3 by default)
- Shows slot number, date of birth, gender icon
- "Play" button loads the character, "✕" deletes it with confirmation

**Character Creation:**
- Spawns a preview ped in an MP Apartment interior (always available)
- **Male model:** `mp_m_freemode_01`
- **Female model:** `mp_f_freemode_01`
- 3 camera presets: Face / Torso / Full body
- 6 customization tabs:
  1. **Heritage** — mother/father mix (0–44), resemblance, skin tone
  2. **Face** — 20 face feature morphs (−1.0 to +1.0)
  3. **Hair** — style (0–73), color (0–63), highlight (0–63)
  4. **Overlays** — blemishes, facial hair, eyebrows, freckles, aging, lipstick, moles, blush
  5. **Eyes** — eye color (0–30)
  6. **Info** — first name, last name, birthday (DD/MM/YYYY)
- **Randomize** button fills all sliders with random values
- Client-side validation + server-side validation (names, date, max chars)
- Phone number generated automatically on creation (format: `555-XXXX`)

---

### `spawn-selector` — Spawn Picker
Shown after a character is loaded, before the player appears in the world.

- Lists all spawn points from `Config.Spawns` in `core/shared/config.lua`
- "Last Location" option loads the saved position from the database
- On selection: teleport + respawn + screen fade in
- Spawn list is translated (labels come from config, UI strings from locale)

---

### `hud` — In-Game HUD
Always visible after spawning. Replaces the default GTA V HUD.

| Position | Element |
|---|---|
| Top-right | Current time (game clock) + zone name |
| Bottom-right | Health bar, Armor bar (only if > 0), Hunger, Thirst, Stress |
| Bottom-left | Cash amount + Bank amount |
| Bottom-center | Vehicle speed in km/h (only when in vehicle) |
| Top-right (stack) | Notification toasts (success / error / info / warning) |

- Updates health and armor every 500ms via a tick thread
- Receives `fivecore:moneyUpdated` and `fivecore:statusUpdated` events
- All notifications from the framework show here (NUI-based, not GTA subtitles)

---

### `text-channel` — Phone & SMS
A phone system accessible with `F2`.

- **Phone number:** auto-generated per character (`555-XXXX`), unique, stored in DB
- **Send SMS:** `/sms 555-1234 Your message here`
- **Rate limit:** max 10 SMS per 60 seconds per player (server-enforced)
- **Offline delivery:** SMS saved to DB even if recipient is offline
- **Online delivery:** if recipient is online, they get an instant notification
- **Phone UI tabs:**
  - **Inbox** — received messages, click to reply
  - **Outbox** — sent messages
  - **Compose** — write new message with character counter (200 max)
- Phone only opens if a character is loaded (`F2` is ignored before login)

---

### `chat` — Custom Chat
Replaces the built-in FiveM chat entirely (`replace_level_loaders 'chat'`).

| Command | Scope | Description |
|---|---|---|
| `T` (key) | Open chat | Radius 30m — local IC chat |
| `/ooc message` | Server-wide | Out-of-character |
| `/me action` | Radius 15m | Roleplay action |
| `/broadcast msg` | Server-wide | Admin only (requires ACE `command`) |
| `/help` | Self | Shows all available commands (translated) |

- All chat is logged to the `logs` table in the database
- Mode tabs in the input bar: LOCAL / OOC / /ME

---

## Database Tables

### `accounts`
| Column | Type | Description |
|---|---|---|
| id | INT AUTO_INCREMENT | Primary key |
| identifier | VARCHAR(100) UNIQUE | Steam/license ID |
| language | VARCHAR(5) | Saved language preference |
| first_join | DATETIME | When account was created |
| last_seen | DATETIME | Updated on every connect |

### `characters`
| Column | Type | Description |
|---|---|---|
| id | INT AUTO_INCREMENT | Primary key |
| account_id | INT FK | Links to accounts |
| slot | TINYINT | Slot number (1–3) |
| firstname/lastname | VARCHAR(50) | Character name |
| dob | VARCHAR(20) | Date of birth |
| gender | TINYINT | 0 = male, 1 = female |
| appearance | JSON | Full appearance data |
| position | JSON | Last position `{x,y,z,h}` |
| status | JSON | `{hunger,thirst,stress}` |
| cash / bank | INT | Money |
| job | JSON | `{name,label,grade}` |
| licenses | JSON | Array of licenses |
| phone | VARCHAR(20) UNIQUE | Phone number |
| created_at | DATETIME | When character was created |

### `sms_messages`
| Column | Type | Description |
|---|---|---|
| id | INT AUTO_INCREMENT | Primary key |
| from_phone | VARCHAR(20) | Sender phone number |
| to_phone | VARCHAR(20) INDEX | Recipient phone number |
| message | TEXT | Message content |
| sent_at | DATETIME | Timestamp |
| is_read | TINYINT | 0 = unread, 1 = read |

### `logs`
| Column | Type | Description |
|---|---|---|
| id | INT AUTO_INCREMENT | Primary key |
| source | INT | Player source ID |
| action | VARCHAR(100) INDEX | Action type |
| details | JSON | Action-specific data |
| timestamp | DATETIME | When it happened |

**Logged actions:** `character_loaded`, `character_created`, `character_deleted`,
`player_spawned`, `money_add`, `money_remove`, `sms_sent`, `chat_local`

---

## Core API Quick Reference

### Server Exports

```lua
-- Get player account info
local account = exports.core:GetAccount(source)
-- { id, identifier, language, first_join, last_seen }

-- Get active (loaded) character
local char = exports.core:GetActiveCharacter(source)
-- { id, accountId, slot, firstname, lastname, fullname, dob, gender,
--   appearance, position, status, cash, bank, job, licenses, phone }

-- Add money (logged automatically)
local newCash = exports.core:AddMoney(source, 500, "job_payment")

-- Remove money (returns false if not enough)
local ok = exports.core:RemoveMoney(source, 100, "shop")

-- Find player by phone number (returns source or nil)
local src = exports.core:GetPlayerByPhone("555-1234")

-- All online players cache
local allPlayers = exports.core:GetAllPlayers()

-- Set / get character state
exports.core:SetCharacterState(source, CHARACTER_STATES.LOADED)
local state = exports.core:GetCharacterState(source)
```

### Key Server Events (outgoing to client)

```lua
-- Sent when a character finishes loading
TriggerClientEvent("fivecore:playerDataLoaded", source, {
    character = char,
    money     = { cash = 500, bank = 2000 },
    position  = { x = 0, y = 0, z = 72, h = 0 },
})

-- Money changed
TriggerClientEvent("fivecore:moneyUpdated", source, { cash = 1000, bank = 2000 })

-- Status tick
TriggerClientEvent("fivecore:statusUpdated", source, { hunger = 95, thirst = 88, stress = 0 })

-- Show notification
TriggerClientEvent("fivecore:notify", source, { text = "Hello!", type = "success" })

-- Loading screen step
TriggerClientEvent("loading:updateStep", source, { step = 2, text = "Loading account..." })
```

### Key Client Events (incoming from server)

```lua
-- Listen for character loaded
AddEventHandler("fivecore:localPlayerLoaded", function(data) ... end)

-- Listen for money update
AddEventHandler("fivecore:localMoneyUpdated", function(data) ... end)

-- Listen for status update
AddEventHandler("fivecore:localStatusUpdated", function(data) ... end)

-- Language changed
AddEventHandler("fivecore:languageChanged", function(lang) ... end)
```

---

## Languages

Configured in `server.cfg`:

```cfg
set fivecore_locales    "de,en,fr,zh"   # available languages
set fivecore_default_lang "en"          # default for new players
```

| Code | Language | Flag |
|---|---|---|
| `en` | English | 🇬🇧 |
| `de` | Deutsch | 🇩🇪 |
| `fr` | Français | 🇫🇷 |
| `zh` | 中文 | 🇨🇳 |

Players pick their language at first login. Saved in `accounts.language`.
All NUIs update instantly when language changes.

---

## Debug Mode

Set in [core/shared/config.lua](../resources/core/shared/config.lua):

```lua
Config.Debug = true   -- enable for development
```

Enables:
- `/tp x y z` — teleport to coordinates
- `/addmoney 500` — add money to your character
- Extra `[CORE]` log output in server console

**Set `Config.Debug = false` before going live.**
