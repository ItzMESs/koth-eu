local infantry = false
local medic = false
local explosives = false
local marksmamb = false
local support = false
local usemedkit = false

local pickup = 'PICKUP_HEALTH_STANDARD'
local healCount = 0
local healNotifSend = true



-- ============================================================
--  Medkits (medic) and ammo bags (support) on the ground.
--  Server: server/server_class.lua
-- ============================================================

local DROP_RADIUS = 2.5          -- metres: stand inside the green circle
local HEAL_PER_TICK = 10         -- health per second from a medkit
local AMMO_PER_USE = 60          -- ammo per use from an ammo bag
local AMMO_COOLDOWN = 15000      -- ms between ammo refills from the same bag

local MODELS = { med = "prop_ld_health_pack", ammo = "prop_ld_ammo_pack_01" }
local drops = {}                 -- [id] = { data, obj }
local lastAmmo = {}              -- [id] = GetGameTimer()

local function loadModel(name)
    local h = GetHashKey(name)
    RequestModel(h)
    local t = GetGameTimer() + 3000
    while not HasModelLoaded(h) and GetGameTimer() < t do Wait(0) end
    return h
end

RegisterNetEvent("KOTH-Gadget:Add")
AddEventHandler("KOTH-Gadget:Add", function(d)
    if drops[d.id] then return end
    local h = loadModel(MODELS[d.kind] or MODELS.med)
    local obj = CreateObject(h, d.coords.x, d.coords.y, d.coords.z - 0.9, false, false, false)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetEntityCollision(obj, false, false)
    SetModelAsNoLongerNeeded(h)
    local c = GetEntityCoords(obj)
    d.ground = vector3(c.x, c.y, c.z)
    drops[d.id] = { data = d, obj = obj }
end)

RegisterNetEvent("KOTH-Gadget:Remove")
AddEventHandler("KOTH-Gadget:Remove", function(id)
    local e = drops[id]
    if e then
        if DoesEntityExist(e.obj) then DeleteObject(e.obj) end
        drops[id] = nil
        lastAmmo[id] = nil
    end
end)

Citizen.CreateThread(function()
    Wait(5000)
    TriggerServerEvent("KOTH-Gadget:Sync")
end)

-- green circle for own team's drops (ammo bags get a lighter ring)
Citizen.CreateThread(function()
    while true do
        local any = false
        local me = GetEntityCoords(PlayerPedId())
        for _, e in pairs(drops) do
            local d = e.data
            if d.team == KOTH.TeamID and #(me - d.ground) < 80.0 then
                any = true
                local r, g, b = 34, 197, 94
                if d.kind == "ammo" then r, g, b = 132, 204, 22 end
                DrawMarker(27, d.ground.x, d.ground.y, d.ground.z + 0.03, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    DROP_RADIUS * 2.0, DROP_RADIUS * 2.0, 1.0, r, g, b, 170, false, false, 2, true, nil, nil, false)
            end
        end
        Wait(any and 0 or 500)
    end
end)

-- effects for team mates standing in the circle
Citizen.CreateThread(function()
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        if not IsEntityDead(ped) then
            local me = GetEntityCoords(ped)
            for id, e in pairs(drops) do
                local d = e.data
                if d.team == KOTH.TeamID and #(me - d.ground) <= DROP_RADIUS + 0.5 then
                    if d.kind == "med" then
                        local hp, max = GetEntityHealth(ped), GetEntityMaxHealth(ped)
                        if hp < max then
                            SetEntityHealth(ped, math.min(max, hp + HEAL_PER_TICK))
                            TriggerServerEvent("KOTH-Gadget:Used", id)
                        end
                    elseif d.kind == "ammo" then
                        local _, w = GetCurrentPedWeapon(ped, true)
                        if w and w ~= GetHashKey("WEAPON_UNARMED") and GetGameTimer() - (lastAmmo[id] or 0) > AMMO_COOLDOWN then
                            lastAmmo[id] = GetGameTimer()
                            AddAmmoToPed(ped, w, AMMO_PER_USE)
                            PlaySoundFrontend(-1, "PICK_UP", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                            local who = GetPlayerFromServerId(d.owner)
                            TriggerEvent("KOTH:RightNotification", -1, -1, "+" .. AMMO_PER_USE .. " ammo" .. ((who ~= -1 and who ~= PlayerId()) and (" from " .. GetPlayerName(who)) or ""))
                            TriggerServerEvent("KOTH-Gadget:Used", id)
                        end
                    end
                end
            end
        end
    end
end)

AddEventHandler("onResourceStop", function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, e in pairs(drops) do
        if DoesEntityExist(e.obj) then DeleteObject(e.obj) end
    end
end)

RegisterNetEvent("core:Repair")
AddEventHandler("core:Repair", function(net)
    local veh = NetworkGetEntityFromNetworkId(net)
    SetVehicleFixed(veh)
    SetVehicleDeformationFixed(veh)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleEngineHealth(veh, 1000.0)
end)

--[[ Citizen.CreateThread(function()
    while true do
        Citizen.Wait(2000*60)
        print("Delete Health Medic")
        for src,data in pairs(po) do
            if DoesPickupExist(data.pickup) then
                RemovePickup(data.pickup)
                po = {}
            end
        end
    end
end) ]]

Citizen.CreateThread(function()
    while true do
        Wait(15*60000)
        TriggerServerEvent("KOTH-PLAYGAME", Pass["tokenserver"])
    end
end)