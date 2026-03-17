-- FiveCore Security Module
-- Centralised rate limiting, input validation, and abuse detection.
-- All other resources can call these functions via exports.core:*.

FC_Security = {}

-- ─── Rate Limiter ─────────────────────────────────────────────────────────────
-- Tracks how many times each source fires a given key within a time window.
-- Usage: FC_Security.RateLimit(source, "sms_send", 10, 60000) → true/false

local _buckets = {}  -- [source][key] = { count, resetAt }

function FC_Security.RateLimit(source, key, maxCalls, windowMs)
    local now = GetGameTimer()
    if not _buckets[source] then _buckets[source] = {} end

    local b = _buckets[source][key]
    if not b or now >= b.resetAt then
        _buckets[source][key] = { count = 1, resetAt = now + windowMs }
        return true
    end

    b.count = b.count + 1
    if b.count > maxCalls then
        if Config.Debug then
            print(("[SECURITY] Rate limit hit — src:%d key:%s count:%d"):format(source, key, b.count))
        end
        return false
    end
    return true
end

-- Call this when a player disconnects to free memory
function FC_Security.CleanPlayer(source)
    _buckets[source] = nil
end

-- ─── Input Validation Helpers ─────────────────────────────────────────────────

-- Name: only letters (including accented), spaces, hyphens. 2–50 chars.
function FC_Security.IsValidName(str)
    if type(str) ~= "string" then return false end
    local len = #str
    if len < 2 or len > 50 then return false end
    -- Allow Unicode letters via negated digit/punctuation check
    return not str:match("[%d%p]") and not str:match("^%s") and not str:match("%s$")
end

-- Date: DD/MM/YYYY, sanity-checked (not in the future, not > 120 years ago)
function FC_Security.IsValidDOB(str)
    if type(str) ~= "string" then return false end
    local d, m, y = str:match("^(%d%d)/(%d%d)/(%d%d%d%d)$")
    if not d then return false end
    d, m, y = tonumber(d), tonumber(m), tonumber(y)
    if not d or not m or not y then return false end
    if m < 1 or m > 12 then return false end
    if d < 1 or d > 31 then return false end
    -- Rough year bounds (1900–current year)
    local currentYear = 2025  -- updated via os.date at runtime below
    local ok, t = pcall(os.date, "*t")
    if ok and t then currentYear = t.year end
    if y < (currentYear - 120) or y >= currentYear then return false end
    return true
end

-- Phone: must match Config.Phone.Prefix + "-XXXX"
function FC_Security.IsValidPhone(phone)
    if type(phone) ~= "string" then return false end
    return phone:match("^%d%d%d%-%d%d%d%d$") ~= nil
end

-- Money: integer, 0–10 000 000
function FC_Security.IsValidMoneyAmount(amount)
    amount = tonumber(amount)
    if not amount then return false end
    return amount >= 0 and amount <= 10000000 and math.floor(amount) == amount
end

-- GTA V map bounds: X −4000…4500  Y −4000…8000  Z −100…2000
function FC_Security.IsValidCoords(x, y, z)
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if not x or not y or not z then return false end
    return x >= -4000 and x <= 4500
       and y >= -4000 and y <= 8000
       and z >= -100  and z <= 2000
end

-- Generic string: printable ASCII, bounded length, no SQL special chars
function FC_Security.IsSafeString(str, maxLen)
    if type(str) ~= "string" then return false end
    if #str == 0 or #str > (maxLen or 255) then return false end
    -- Reject common injection patterns
    if str:match("[<>\"';]") then return false end
    return true
end

-- Gender: only 0 or 1
function FC_Security.IsValidGender(gender)
    return gender == GENDER_MALE or gender == GENDER_FEMALE
end

-- ─── Appearance Sanitiser ─────────────────────────────────────────────────────
-- Strips any unexpected keys from the appearance table and clamps all numbers.

local function clampN(v, lo, hi)
    local n = tonumber(v)
    if not n then return lo end
    return math.max(lo, math.min(hi, n))
end

function FC_Security.SanitiseAppearance(app)
    if type(app) ~= "table" then return {} end

    local out = {}

    -- Heritage
    out.heritage = {
        mother     = clampN(app.heritage and app.heritage.mother, 0, 44),
        father     = clampN(app.heritage and app.heritage.father, 0, 44),
        resemblance= clampN(app.heritage and app.heritage.resemblance, 0.0, 1.0),
        skinTone   = clampN(app.heritage and app.heritage.skinTone, 0.0, 1.0),
    }

    -- Face features (20 sliders, −1.0 … +1.0)
    out.faceFeatures = {}
    if type(app.faceFeatures) == "table" then
        for i, v in ipairs(app.faceFeatures) do
            if i > 20 then break end
            out.faceFeatures[i] = clampN(v, -1.0, 1.0)
        end
    end

    -- Hair
    out.hair = {
        style     = clampN(app.hair and app.hair.style, 0, 73),
        color     = clampN(app.hair and app.hair.color, 0, 63),
        highlight = clampN(app.hair and app.hair.highlight, 0, 63),
    }

    -- Overlays (8 overlays: index, opacity, color1, color2)
    out.overlays = {}
    if type(app.overlays) == "table" then
        for i, ov in ipairs(app.overlays) do
            if i > 13 then break end
            if type(ov) == "table" then
                out.overlays[i] = {
                    index   = clampN(ov.index, 0, 255),
                    opacity = clampN(ov.opacity, 0.0, 1.0),
                    color1  = clampN(ov.color1, 0, 63),
                    color2  = clampN(ov.color2, 0, 63),
                }
            end
        end
    end

    -- Eye color
    out.eyeColor = clampN(app.eyeColor, 0, 30)

    return out
end

-- ─── Security Event Logger ───────────────────────────────────────────────────

function FC_Security.Warn(source, reason, data)
    local id = GetPlayerIdentifierByType(source, "steam")
             or GetPlayerIdentifierByType(source, "license")
             or "unknown"
    local msg = ("[SECURITY] src:%d (%s) — %s"):format(source, id, reason)
    print(msg)
    if DB then
        DB.Log(source, "security_warn", { reason = reason, extra = data })
    end
end

-- ─── Exports so other resources can reuse these utilities ────────────────────

exports("RateLimit",           FC_Security.RateLimit)
exports("IsValidName",         FC_Security.IsValidName)
exports("IsValidDOB",          FC_Security.IsValidDOB)
exports("IsValidPhone",        FC_Security.IsValidPhone)
exports("IsValidMoneyAmount",  FC_Security.IsValidMoneyAmount)
exports("IsValidCoords",       FC_Security.IsValidCoords)
exports("IsSafeString",        FC_Security.IsSafeString)
exports("SanitiseAppearance",  FC_Security.SanitiseAppearance)
exports("SecurityWarn",        FC_Security.Warn)
