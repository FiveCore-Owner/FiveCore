-- Loading Screen — Client Script
-- Adapted from the ESX esx_loadingscreen + esx_multicharacter pattern.

-- ─── Client-Ready Signal ──────────────────────────────────────────────────────
-- Wait until NetworkIsPlayerActive, exactly like ESX multicharacter does.
-- By this point ALL resource client scripts have executed and every
-- RegisterNetEvent call has completed — no more "not safe for net".

CreateThread(function()
    local playerId = PlayerId()
    while not NetworkIsPlayerActive(playerId) do
        Wait(100)
    end

    -- Disable FiveM's built-in spawn manager so the player is NOT
    -- auto-spawned at the default location (same as ESX.DisableSpawnManager).
    if GetResourceState("spawnmanager") == "started" then
        exports.spawnmanager:setAutoSpawn(false)
    end

    -- Fade to black so the transition to the character creator interior is seamless.
    DoScreenFadeOut(0)

    -- Signal server — FC_LoadPlayer will now run with all events registered.
    TriggerServerEvent("fivecore:clientReady")
end)

-- ─── Step Progress → NUI ──────────────────────────────────────────────────────
-- Forwards step events to the loadscreen HTML for the progress bar.
-- Loading screen shutdown is handled by OpenCreator() in character-creator,
-- NOT here (same pattern as ESX calling ShutdownLoadingScreen in SetupCharacters).

RegisterNetEvent("loading:updateStep")
AddEventHandler("loading:updateStep", function(data)
    local step = type(data) == "table" and data.step or tonumber(data) or 1
    SendNUIMessage({ type = "updateStep", step = step })
end)

-- ─── Language → NUI ───────────────────────────────────────────────────────────

RegisterNetEvent("fivecore:setLanguage")
AddEventHandler("fivecore:setLanguage", function(lang)
    local locale = Locales and (Locales[lang] or Locales['en']) or nil
    SendNUIMessage({ type = "setLang", lang = lang, locale = locale })
end)

-- ─── Branding + Tips ConVars → NUI ───────────────────────────────────────────

AddEventHandler("onClientResourceStart", function(res)
    if res ~= GetCurrentResourceName() then return end

    local title    = GetConvar("LoadingscreenTitle",    "FIVECORE")
    local bio      = GetConvar("Loadingscreenbio",      "Roleplay")
    local showTips = GetConvar("Loadingscreentipplist", "true"):lower()

    local customTips = {}
    for i = 1, 20 do
        local v = GetConvar("Loadingscreentipp" .. i, "")
        if v ~= "" then
            table.insert(customTips, v)
        else
            break
        end
    end

    SendNUIMessage({
        type       = "setBranding",
        title      = title,
        bio        = bio,
        showTips   = (showTips ~= "false"),
        customTips = #customTips > 0 and customTips or nil,
    })
end)
