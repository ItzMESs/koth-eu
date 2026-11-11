-- Killstreaks: pick 3 (K), progress on the HUD, use the next ready one (4)

local state = { streak = 0, used = {}, killstreaks = {}, selected = {}, prestige = 0, slots = 3 }
local KS = {}
local uavBlips = {}

local function hud()
    Plus.Send("ks", "hud", state)
end

RegisterNetEvent("KOTH-Plus:State")
AddEventHandler("KOTH-Plus:State", function(s)
    state = s
    KS = {}
    for _, k in ipairs(s.killstreaks or {}) do KS[k.id] = k end
    hud()
end)

RegisterCommand("killstreaks", function()
    Plus.Open("ks", state)
end, false)
RegisterKeyMapping("killstreaks", "Choose killstreaks", "keyboard", "K")

RegisterNUICallback("ksSelect", function(data, cb)
    TriggerServerEvent("KOTH-Plus:SetKillstreaks", data.list or {})
    Plus.Close()
    cb("ok")
end)

-- use the lowest ready, unused killstreak
RegisterCommand("+ksuse", function()
    if IsEntityDead(PlayerPedId()) then return end
    for _, id in ipairs(state.selected or {}) do
        local k = KS[id]
        if k and not (state.used or {})[id] and (state.streak or 0) >= k.kills then
            TriggerServerEvent("KOTH-Plus:UseKillstreak", id)
            return
        end
    end
end, false)
RegisterCommand("-ksuse", function() end, false)
RegisterKeyMapping("+ksuse", "Use killstreak", "keyboard", "4")

-- ---------- effects ----------
local function strike(target, count, spread, delay, kind)
    local ped = PlayerPedId()
    Citizen.CreateThread(function()
        local untilT = GetGameTimer() + delay
        while GetGameTimer() < untilT do
            DrawMarker(1, target.x, target.y, target.z - 1.0, 0, 0, 0, 0, 0, 0, spread * 2.0, spread * 2.0, 60.0, 239, 68, 68, 90, false, false, 2, false, nil, nil, false)
            Wait(0)
        end
        for i = 1, count do
            local a = math.random() * math.pi * 2
            local r = math.random() * spread
            AddOwnedExplosion(ped, target.x + math.cos(a) * r, target.y + math.sin(a) * r, target.z, kind, 1.0, true, false, 1.0)
            Wait(250)
        end
    end)
end

RegisterNetEvent("KOTH-Plus:KillstreakGo")
AddEventHandler("KOTH-Plus:KillstreakGo", function(id)
    local ped = PlayerPedId()
    local k = KS[id]
    Plus.Send("bigmsg", "show", { title = (k and k.label or id):upper(), sub = "Killstreak activated", color = "red" })

    if id == "supply" then
        SetEntityHealth(ped, GetEntityMaxHealth(ped))
        local _, w = GetCurrentPedWeapon(ped, true)
        if w and w ~= GetHashKey("WEAPON_UNARMED") then AddAmmoToPed(ped, w, 250) end
        TriggerEvent("KOTH-AC:AllowArmour", 600) -- koth-main anti-cheat
        SetPedArmour(ped, math.max(GetPedArmour(ped), 50))
    elseif id == "armor" then
        TriggerEvent("KOTH-AC:AllowArmour", 600) -- koth-main anti-cheat
        SetPedArmour(ped, 100)
    elseif id == "airstrike" or id == "precision" or id == "cluster" then
        local target = Plus.RayFromCamera(500.0)
        if not target then
            local c = GetEntityCoords(ped)
            local f = GetEntityForwardVector(ped)
            target = c + f * 60.0
        end
        if id == "airstrike" then strike(target, 3, 8.0, 5000, 5)
        elseif id == "precision" then strike(target, 1, 1.0, 2000, 5)
        else strike(target, 6, 20.0, 5000, 5) end
    end
end)

-- UAV pings from the server: red blips on enemies for 30 seconds
RegisterNetEvent("KOTH-Plus:UavPing")
AddEventHandler("KOTH-Plus:UavPing", function(enemies, by)
    for _, b in pairs(uavBlips) do RemoveBlip(b) end
    uavBlips = {}
    if not enemies then return end
    for _, e in ipairs(enemies) do
        local b = AddBlipForCoord(e.x, e.y, e.z)
        SetBlipSprite(b, 1)
        SetBlipColour(b, 1)
        SetBlipScale(b, 0.75)
        SetBlipAsShortRange(b, false)
        uavBlips[#uavBlips + 1] = b
    end
end)

RegisterNetEvent("KOTH-Plus:KillstreakUsed")
AddEventHandler("KOTH-Plus:KillstreakUsed", function(info)
    Plus.Send("toast", "show", { text = info.by .. " called in " .. info.label, kind = "ks" })
end)
