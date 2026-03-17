Config = {}

-- Environment
Config.Debug       = true       -- true = Dev-Mode (extra logs, /tp, schnell-login)
Config.Environment = "dev"      -- "dev" | "prod"

-- Sprache (aus server.cfg ConVars, kein /lang-Command nötig)
-- Werte kommen von: set fivecore_locales "de,en,fr,zh"
--                   set fivecore_default_lang "de"
Config.AvailableLanguages = {}   -- wird beim Start aus ConVar befüllt
Config.DefaultLang        = "en" -- Fallback falls ConVar nicht gesetzt

-- Character limits
Config.MaxCharacters = 3

-- Status tick (ms) — wie oft Hunger/Durst/Stress verringert wird
Config.StatusTickInterval = 30000

-- Auto-save interval (ms)
Config.AutoSaveInterval = 300000 -- 5 Minuten

-- Database
Config.Database = {
    AutoMigrate = true,   -- Migrations beim Start ausführen?
}

-- Spawn-Punkte
-- coords = nil bedeutet: letzten gespeicherten Standort laden
Config.Spawns = {
    { label = "Krankenhaus Los Santos", coords = vector4(295.0,  -584.0, 43.0,  45.0) },
    { label = "Bahnhof Los Santos",     coords = vector4(425.0,  -645.0, 28.0,  90.0) },
    { label = "Legion Square",          coords = vector4(195.0,  -930.0, 30.0, 180.0) },
    { label = "Sandy Shores",           coords = vector4(1848.0, 3689.0, 34.0, 270.0) },
    { label = "Paleto Bay",             coords = vector4(-220.0, 6249.0, 31.0,   0.0) },
    { label = "Letzter Standort",       coords = nil },
}

-- Telefon
Config.Phone = {
    Prefix    = "555",   -- Nummern: 555-0000 bis 555-9999
    RateLimit = 10,      -- max SMS pro Minute pro Spieler
}

-- Status-Werte pro Tick (verringern sich)
Config.StatusDrain = {
    hunger = 2,
    thirst = 3,
    stress = 0,  -- Stress erhöht sich durch Aktionen, sinkt durch Schlafen
}

-- Default-Startgeld bei neuem Charakter
Config.StartCash = 500
Config.StartBank = 2000

-- Chat-Radius für /local (Meter)
Config.LocalChatRadius = 30.0
Config.MeChatRadius    = 15.0
