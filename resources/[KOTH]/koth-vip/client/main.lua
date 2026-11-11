-- KOTH VIP menu (client). F5 or /vip
-- Server: koth-main/server/vip.lua (VIP status, XP boost, team bypass, /setvip)

local isVip = false
local perks = {}
local boost = 1.5
local hudOn = true
local myStats = { kills = 0, deaths = 0, assists = 0, score = 0, money = 0 }

-- simple RGB swatches for the colour groups in vehicle.lua (display only)
local SWATCH = {
    black = "#111111", white = "#f2f2f2", grey = "#7a7d80", red = "#c1121f", pink = "#ec4899",
    blue = "#1d4ed8", yellow = "#facc15", green = "#15803d", orange = "#f97316", brown = "#7c4a2d",
    purple = "#7e22ce", chrome = "#c0c6cc", gold = "#c9a227",
}

local TINTS = { "Normal", "Green", "Gold", "Pink", "Army", "LSPD", "Orange", "Platinum" }

-- ask the server for our VIP status
local function requestStatus() TriggerServerEvent("KOTH-VIP:Request") end
AddEventHandler("playerSpawned", requestStatus)
Citizen.CreateThread(function() Wait(3000) requestStatus() end)

RegisterNetEvent("KOTH-VIP:Status")
AddEventHandler("KOTH-VIP:Status", function(vip, p, b)
    isVip = vip and true or false
    perks = p or perks
    boost = b or boost
end)

-- own session stats (scoreboard data, sent every second)
RegisterNetEvent("KOTH-HUD:OPEN")
AddEventHandler("KOTH-HUD:OPEN", function(players)
    local me = GetPlayerServerId(PlayerId())
    for _, v in pairs(players) do
        if v.id == me then
            myStats = { kills = v.kill or 0, deaths = v.death or 0, assists = v.assist or 0, score = v.score or 0, money = v.money or 0 }
        end
    end
end)

local function weaponState()
    local ped = PlayerPedId()
    local _, weapon = GetCurrentPedWeapon(ped, true)
    if not weapon or weapon == GetHashKey("WEAPON_UNARMED") then return nil end

    local id, label = nil, nil
    pcall(function() id, label = exports['koth-main']:GetWeaponInfo(weapon) end)

    local comps, seen = {}, {}
    for name, hash in pairs(WeaponHashKey) do
        if not seen[name] and DoesWeaponTakeWeaponComponent(weapon, hash) then
            seen[name] = true
            local text = WeaponHashText[name]
            if not text or text == "" or text == "NULL" then text = name:gsub("COMPONENT_", ""):gsub("_", " ") end
            comps[#comps + 1] = { id = name, label = text, on = HasPedGotWeaponComponent(ped, weapon, hash) }
        end
    end
    table.sort(comps, function(a, b) return a.label < b.label end)

    return { id = id, label = label or "Current weapon", components = comps, tint = GetPedWeaponTintIndex(ped, weapon), tints = TINTS }
end

local function vehicleState()
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then return nil end
    local groups = {}
    for _, c in ipairs(Colors) do
        local list = {}
        for _, col in ipairs(GetColors(c.value)) do list[#list + 1] = { index = col.index, label = col.label } end
        groups[#groups + 1] = { id = c.value, label = c.label, swatch = SWATCH[c.value] or "#888", colors = list }
    end
    local p, s = GetVehicleColours(veh)
    return { name = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(veh))), groups = groups, primary = p, secondary = s }
end

local function state()
    return {
        vip = isVip,
        perks = perks,
        boost = boost,
        name = GetPlayerName(PlayerId()),
        serverId = GetPlayerServerId(PlayerId()),
        stats = myStats,
        hud = hudOn,
        weapon = weaponState(),
        vehicle = vehicleState(),
    }
end

local function openMenu()
    SendNUIMessage({ action = "open", data = state() })
    SetNuiFocus(true, true)
end

RegisterCommand("vip", openMenu, false)
RegisterKeyMapping("vip", "Open VIP menu", "keyboard", "F5")

RegisterNUICallback("close", function(_, cb)
    SetNuiFocus(false, false)
    cb("ok")
end)

RegisterNUICallback("toggleHud", function(data, cb)
    hudOn = data.on and true or false
    TriggerEvent("KOTH_HUD:removeHUD", hudOn and 2 or 1)
    cb("ok")
end)

-- everything below is VIP only
RegisterNUICallback("toggleComponent", function(data, cb)
    if isVip and WeaponHashKey[data.id] then
        local ped = PlayerPedId()
        local _, weapon = GetCurrentPedWeapon(ped, true)
        local hash = WeaponHashKey[data.id]
        if HasPedGotWeaponComponent(ped, weapon, hash) then
            RemoveWeaponComponentFromPed(ped, weapon, hash)
        elseif DoesWeaponTakeWeaponComponent(weapon, hash) then
            GiveWeaponComponentToPed(ped, weapon, hash)
        end
    end
    cb({ weapon = weaponState() })
end)

RegisterNUICallback("setTint", function(data, cb)
    if isVip then
        local ped = PlayerPedId()
        local _, weapon = GetCurrentPedWeapon(ped, true)
        SetPedWeaponTintIndex(ped, weapon, tonumber(data.index) or 0)
    end
    cb({ weapon = weaponState() })
end)

RegisterNUICallback("setVehColor", function(data, cb)
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if isVip and veh ~= 0 and GetPedInVehicleSeat(veh, -1) == PlayerPedId() then
        if data.slot == "secondary" then
            SetVehicleProperties(veh, { color2 = tonumber(data.index) })
        else
            SetVehicleProperties(veh, { color1 = tonumber(data.index) })
        end
    end
    cb({ vehicle = vehicleState() })
end)
