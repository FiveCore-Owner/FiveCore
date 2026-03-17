-- FiveCore Death Screen

local isDead     = false
local deathTimer = 0
local BLEED_TIME = 300  -- Sekunden, bevor Spieler respawnt (Config überschreibt)

-- ─── Spieler-Status ──────────────────────────────────────────────────────────

local playerLoaded = false
AddEventHandler("fivecore:localPlayerSpawned", function()
    playerLoaded = true
    isDead = false
    SendNUIMessage({ type = "hide" })
end)

-- ─── Death Detection Thread ───────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(500)
        if not playerLoaded then goto dskip end

        local ped = PlayerPedId()
        local hp  = GetEntityHealth(ped)

        if hp <= 100 and not isDead then
            -- Spieler gerade gestorben
            isDead     = true
            deathTimer = (Config.DeathScreenTime or BLEED_TIME)

            -- Spiel-Respawn blockieren
            SetEntityInvincible(ped, true)

            -- Death Screen öffnen
            local locale = Locales[ClientLang] or Locales['en']
            SendNUIMessage({
                type     = "show",
                timer    = deathTimer,
                locale   = locale,
            })

            -- GTA HUD bei Tod ausblenden
            DisplayHud(false)
            DisplayRadar(false)

            if Config.Debug then print("[DEATH] Spieler ist gestorben") end

        elseif hp > 100 and isDead then
            -- Spieler wurde wiederbelebt (z.B. von Sanitäter)
            isDead = false
            SendNUIMessage({ type = "hide" })
            SetEntityInvincible(ped, false)
            DisplayHud(true)
            DisplayRadar(true)
        end

        ::dskip::
    end
end)

-- ─── Countdown Thread ────────────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(1000)
        if not isDead then goto cskip end

        deathTimer = deathTimer - 1
        SendNUIMessage({ type = "tick", timer = deathTimer })

        if deathTimer <= 0 then
            -- Auto-Respawn: Spieler wird ins Krankenhaus teleportiert
            isDead = false
            SendNUIMessage({ type = "hide" })

            local ped = PlayerPedId()
            SetEntityInvincible(ped, false)

            -- Respawn-Event an Server
            TriggerServerEvent("deathscreen:respawn")
        end

        ::cskip::
    end
end)

-- ─── NUI Callbacks ───────────────────────────────────────────────────────────

RegisterNUICallback("callAmbulance", function(_, cb)
    TriggerServerEvent("deathscreen:callAmbulance")
    cb({})
end)

-- ─── Server: Respawn ─────────────────────────────────────────────────────────

RegisterNetEvent("deathscreen:doRespawn", function(coords)
    isDead = false
    SendNUIMessage({ type = "hide" })

    local ped = PlayerPedId()
    SetEntityInvincible(ped, false)

    DoScreenFadeOut(500)
    while IsScreenFadingOut() do Wait(100) end

    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, coords.w or 0.0, true, false)
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, true)
    SetEntityHeading(ped, coords.w or 0.0)
    SetEntityHealth(ped, 200) -- 100 HP nach Respawn

    Wait(300)
    DoScreenFadeIn(750)

    TriggerEvent("fivecore:localPlayerSpawned")
    if Config.Debug then print("[DEATH] Spieler respawnt") end
end)

AddEventHandler("fivecore:languageChanged", function(lang)
    if isDead then
        SendNUIMessage({ type = "setLang", locale = Locales[lang] or Locales['en'] })
    end
end)
