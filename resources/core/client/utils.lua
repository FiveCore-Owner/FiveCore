-- FiveCore Client Utilities

-- ─── Notification ────────────────────────────────────────────────────────────

local notifyQueue = {}
local notifyActive = false

local NOTIFY_COLORS = {
    success = { r=80,  g=200, b=80,  a=220 },
    error   = { r=220, g=60,  b=60,  a=220 },
    info    = { r=80,  g=160, b=220, a=220 },
    warning = { r=230, g=170, b=40,  a=220 },
}

local function DrawNextNotify()
    if notifyActive or #notifyQueue == 0 then return end
    notifyActive = true
    local n = table.remove(notifyQueue, 1)
    local col = NOTIFY_COLORS[n.type] or NOTIFY_COLORS.info

    CreateThread(function()
        local timer = GetGameTimer()
        local duration = n.duration or 4000
        while GetGameTimer() - timer < duration do
            Wait(0)
            -- NUI-Notify bevorzugt (wird von hud resource gehandelt)
            -- Fallback: GTA-native Subtitle
            SetTextFont(0)
            SetTextScale(0.0, 0.4)
            SetTextColour(col.r, col.g, col.b, col.a)
            SetTextJustification(0)
            SetTextCentre(true)
            SetTextOutline()
            BeginTextCommandDisplayText("STRING")
            AddTextComponentSubstringPlayerName(n.text)
            EndTextCommandDisplayText(0.5, 0.93)
        end
        notifyActive = false
        DrawNextNotify()
    end)
end

AddEventHandler("fivecore:showNotify", function(data)
    table.insert(notifyQueue, data)
    DrawNextNotify()
end)

-- Auch direkt aufrufbar
function FC_Notify(text, notifyType, duration)
    TriggerEvent("fivecore:showNotify", {
        text     = text,
        type     = notifyType or NOTIFY_TYPES.INFO,
        duration = duration or 4000,
    })
end

-- ─── DrawText3D ──────────────────────────────────────────────────────────────

function FC_DrawText3D(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    local p = GetGameplayCamCoords()
    local dist = #(vector3(p.x, p.y, p.z) - vector3(x, y, z))
    if onScreen and dist < 20.0 then
        local scale = (1 / dist) * 2
        local fov = (1 / GetGameplayCamFov()) * 100
        scale = scale * fov
        SetTextScale(0.0, math.min(scale, 0.5))
        SetTextFont(0)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(sx, sy)
    end
end

-- ─── HelpText (Taste drücken...) ─────────────────────────────────────────────

function FC_ShowHelpText(text)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- ─── Spieler in Reichweite ───────────────────────────────────────────────────

function FC_GetPlayersInRadius(coords, radius)
    local players = {}
    for _, pid in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(pid)
        if ped and ped ~= 0 then
            local pcoords = GetEntityCoords(ped)
            if #(coords - pcoords) <= radius then
                table.insert(players, pid)
            end
        end
    end
    return players
end
