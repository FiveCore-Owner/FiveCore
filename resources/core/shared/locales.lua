-- FiveCore i18n System
-- Verwendung: T(source, 'key') auf Server | T('key') auf Client

Locales = {}

SUPPORTED_LANGS = { 'en', 'fr', 'de', 'zh' }
DEFAULT_LANG    = 'en'

-- ─── Server: Per-Spieler-Sprache ─────────────────────────────────────────────
-- (nur auf Server relevant; auf Client wird Config.ClientLang gesetzt)

if IsDuplicityVersion() then
    -- Server-seitig: pro Spieler eine Sprachpräferenz
    PlayerLanguages = {}   -- PlayerLanguages[source] = 'de'

    function GetPlayerLang(source)
        return PlayerLanguages[source] or DEFAULT_LANG
    end

    function SetPlayerLang(source, lang)
        if not Locales[lang] then return false end
        PlayerLanguages[source] = lang
        return true
    end

    -- Übersetzung für einen bestimmten Spieler
    function T(source, key, ...)
        local lang   = GetPlayerLang(source)
        local locale = Locales[lang] or Locales[DEFAULT_LANG] or {}
        local str    = locale[key] or (Locales[DEFAULT_LANG] or {})[key] or key
        if select('#', ...) > 0 then
            local ok, result = pcall(string.format, str, ...)
            return ok and result or str
        end
        return str
    end

    -- Übersetzung ohne Spieler-Kontext (z.B. für Server-Logs)
    function TServer(key, ...)
        local locale = Locales[DEFAULT_LANG] or {}
        local str    = locale[key] or key
        if select('#', ...) > 0 then
            local ok, result = pcall(string.format, str, ...)
            return ok and result or str
        end
        return str
    end

else
    -- Client-seitig: eine globale Sprache für diesen Client
    ClientLang = DEFAULT_LANG

    function SetClientLang(lang)
        if Locales[lang] then
            ClientLang = lang
        end
    end

    -- T('key', ...) — kein source-Parameter auf Client
    function T(key, ...)
        local locale = Locales[ClientLang] or Locales[DEFAULT_LANG] or {}
        local str    = locale[key] or (Locales[DEFAULT_LANG] or {})[key] or key
        if select('#', ...) > 0 then
            local ok, result = pcall(string.format, str, ...)
            return ok and result or str
        end
        return str
    end
end
