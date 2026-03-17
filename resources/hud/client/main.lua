-- FiveCore HUD Client

local hudVisible  = false
local hudData     = {
    health  = 100,
    armour  = 0,
    hunger  = 100,
    thirst  = 100,
    stress  = 0,
    cash    = 0,
    bank    = 0,
    zone    = "Los Santos",
    time    = "00:00",
    inVehicle = false,
    speed     = 0,
}

-- ─── HUD anzeigen ────────────────────────────────────────────────────────────

local function ShowHUD()
    hudVisible = true
    SendNUIMessage({ type = "show" })
    SendNUIMessage({ type = "update", data = hudData })
end

local function HideHUD()
    hudVisible = false
    SendNUIMessage({ type = "hide" })
end

-- ─── Charakter geladen → HUD einblenden ──────────────────────────────────────

AddEventHandler(EVENTS.PLAYER_LOADED, function(data)
    if data and data.money then
        hudData.cash = data.money.cash or 0
        hudData.bank = data.money.bank or 0
    end
    if data and data.character and data.character.status then
        hudData.hunger = data.character.status.hunger or 100
        hudData.thirst = data.character.status.thirst or 100
        hudData.stress = data.character.status.stress or 0
    end
    Wait(1000)
    ShowHUD()
end)

-- Lokales Event nach Spawn
AddEventHandler("fivecore:localPlayerLoaded", function()
    Wait(1500)
    if not hudVisible then ShowHUD() end
end)

-- ─── Geld-Update ─────────────────────────────────────────────────────────────

AddEventHandler("fivecore:localMoneyUpdated", function(data)
    hudData.cash = data.cash or 0
    hudData.bank = data.bank or 0
    SendNUIMessage({ type = "updateMoney", cash = hudData.cash, bank = hudData.bank })
end)

-- ─── Status-Update ───────────────────────────────────────────────────────────

AddEventHandler("fivecore:localStatusUpdated", function(data)
    hudData.hunger = data.hunger or 100
    hudData.thirst = data.thirst or 100
    hudData.stress = data.stress or 0
    SendNUIMessage({ type = "updateStatus", hunger = hudData.hunger, thirst = hudData.thirst, stress = hudData.stress })
end)

-- ─── HUD Tick ────────────────────────────────────────────────────────────────

local function GetZoneName(x, y, z)
    local zone = GetNameOfZone(x, y, z)
    -- Bekannte Zonen-Labels
    local labels = {
        AIRP   = "Flughafen",
        ALAMO  = "Alamo Sea",
        ALTA   = "Alta",
        ARMYB  = "Fort Zancudo",
        BANHAMC= "Banham Canyon",
        BANNING= "Banning",
        BEACH  = "Vespucci Beach",
        BHAMCA = "Banham Canyon",
        BRADP  = "Braddock Pass",
        BRADT  = "Braddock Tunnel",
        BURTON = "Burton",
        CALAFB = "Calafia Bridge",
        CANNY  = "Raton Canyon",
        CCREAK = "Cassidy Creek",
        CHAMH  = "Chamberlain Hills",
        CHIL   = "Vinewood Hills",
        CHU    = "Chumash",
        CMSW   = "Chiliad Mountain",
        CYPRE  = "Cypress Flats",
        DAVIS  = "Davis",
        DELBE  = "Del Perro Beach",
        DELPE  = "Del Perro",
        DELSOL = "La Mesa",
        DESRT  = "Grand Senora Desert",
        DOWNT  = "Downtown",
        DTVINE = "Downtown Vinewood",
        EAST_V = "East Vinewood",
        ELGORL = "El Gordo Lighthouse",
        ELYSIAN= "Elysian Island",
        GALFISH= "Galilee",
        GOLF   = "GWC and Golfing Society",
        GRAPES = "Grapeseed",
        GREATC = "Great Chaparral",
        HARMO  = "Harmony",
        HAWICK = "Hawick",
        HORS   = "Vinewood Racetrack",
        HUMLAB = "Humane Labs",
        ISHEIST= "Cayo Perico",
        JAIL   = "Bolingbroke Penitentiary",
        KOREAT = "Koreatow",
        LACT   = "Land Act Reservoir",
        LAGO   = "Lago Zancudo",
        LDAM   = "Land Act Dam",
        LEGSQU = "Legion Square",
        LMESA  = "La Mesa",
        LOSPUER= "La Puerta",
        LOTINT = "Little Seoul",
        LOUT   = "Downtown Los Santos",
        MIRRP  = "Mirror Park",
        MORN   = "Morningwood",
        MOVIE  = "Richards Majestic",
        MTCHIL = "Mount Chiliad",
        MTGORDO= "Mount Gordo",
        MTJOSE = "Mount Josiah",
        MURRI  = "Murrieta Heights",
        NCHU   = "North Chumash",
        NOOSE  = "N.O.O.S.E",
        OCEANA = "Pacific Ocean",
        PALCOV = "Paleto Cove",
        PALETO = "Paleto Bay",
        PALFOR = "Paleto Forest",
        PALHIGH= "Palomino Highlands",
        PALMPOW= "Palmer-Taylor Power Station",
        PBLUFF = "Pacific Bluffs",
        PBOX   = "Pillbox Hill",
        PBROACH= "Procopio Beach",
        PROCOB = "Procopio Beach",
        PROL   = "North Yankton",
        PRPIE  = "Procopio Beach",
        PSTAB  = "Pillbox Hill",
        PBLUFF = "Pacific Bluffs",
        PBOX   = "Pillbox Hill",
        RANCHO = "Rancho",
        RGLEN  = "Richman Glen",
        RICHM  = "Richman",
        ROCKF  = "Rockford Hills",
        RTRAK  = "Redwood Lights Track",
        SANAND = "San Andreas",
        SANCHIA= "San Chianski Mountain Range",
        SANDY  = "Sandy Shores",
        SKID   = "Mission Row",
        SLAB   = "Stab City",
        STAD   = "Maze Bank Arena",
        STRAW  = "Strawberry",
        TATAMO = "Tataviam Mountains",
        TERMINA= "Terminal",
        TEXTI  = "Textile City",
        TONGVAH= "Tongva Hills",
        TONGVAV= "Tongva Valley",
        VCANA  = "Vinewood",
        VESP   = "Vespucci",
        VESPA  = "Vespucci Canals",
        VESPBE = "Vespucci Beach",
        VINE   = "Vinewood",
        WINDF  = "Ron Alternates Wind Farm",
        WVINE  = "West Vinewood",
        ZANCUDO= "Zancudo River",
        ZP_ORT = "La Puerta",
        ZQ_UAD = "Davis Quartz",
    }
    return labels[zone] or zone or "Los Santos"
end

CreateThread(function()
    while true do
        Wait(500)
        if not hudVisible then goto continue end

        local ped = PlayerPedId()
        if not DoesEntityExist(ped) then goto continue end

        -- Gesundheit / Panzerung
        local hp     = math.floor(((GetEntityHealth(ped) - 100) / 100) * 100)
        local armour = GetPedArmour(ped)
        hudData.health = math.max(0, math.min(100, hp))
        hudData.armour = math.max(0, math.min(100, armour))

        -- Fahrzeug / Geschwindigkeit
        local veh = GetVehiclePedIsIn(ped, false)
        local inVehicle = veh ~= 0
        local speed = 0
        if inVehicle then
            speed = math.floor(GetEntitySpeed(veh) * 3.6)
        end
        hudData.inVehicle = inVehicle
        hudData.speed     = speed

        -- Zone
        local pos = GetEntityCoords(ped)
        hudData.zone = GetZoneName(pos.x, pos.y, pos.z)

        -- Uhrzeit
        local h, m = GetClockHours(), GetClockMinutes()
        hudData.time = string.format("%02d:%02d", h, m)

        SendNUIMessage({
            type     = "tick",
            health   = hudData.health,
            armour   = hudData.armour,
            inVehicle= inVehicle,
            speed    = speed,
            zone     = hudData.zone,
            time     = hudData.time,
        })

        ::continue::
    end
end)

-- ─── Notify (NUI-basiert) ─────────────────────────────────────────────────────

AddEventHandler("fivecore:showNotify", function(data)
    SendNUIMessage({
        type     = "notify",
        text     = data.text,
        ntype    = data.type or "info",
        duration = data.duration or 4000,
    })
end)

-- ─── Standard-GTA HUD verstecken ─────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(0)
        if hudVisible then
            DisplayRadar(true)
            DisplayHud(false)
        end
    end
end)
