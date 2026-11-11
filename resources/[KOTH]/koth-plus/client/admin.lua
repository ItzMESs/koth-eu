-- Admin panel (F11). All actions are checked on the server (koth-main/server/admin.lua).

local staffMode = false
local noclip, invisible, god = false, false, false
local frozen = false
local spectating = nil       -- { target, pos }

RegisterCommand("admin", function() TriggerServerEvent("KOTH-Admin:Open") end, false)
RegisterKeyMapping("admin", "Open admin panel (staff)", "keyboard", "F11")

RegisterNetEvent("KOTH-Admin:Data")
AddEventHandler("KOTH-Admin:Data", function(data)
    data.self = { noclip = noclip, invisible = invisible, god = god, spectating = spectating ~= nil }
    staffMode = data.staffMode
    Plus.Open("admin", data)
end)

RegisterNetEvent("KOTH-Admin:Players")
AddEventHandler("KOTH-Admin:Players", function(players, reports)
    Plus.Send("admin", "players", { players = players, reports = reports })
end)

RegisterNetEvent("KOTH-Admin:PlayerInfo")
AddEventHandler("KOTH-Admin:PlayerInfo", function(info) Plus.Send("admin", "info", info) end)

RegisterNetEvent("KOTH-Admin:Bans")
AddEventHandler("KOTH-Admin:Bans", function(list, now) Plus.Send("admin", "bans", { list = list, now = now }) end)

RegisterNetEvent("KOTH-Admin:NewReport")
AddEventHandler("KOTH-Admin:NewReport", function(r)
    Plus.Send("reportToast", "show", r)
    PlaySoundFrontend(-1, "Event_Message_Purple", "GTAO_FM_Events_Soundset", true)
end)

RegisterNUICallback("admin", function(data, cb)
    local a = data.action
    if a == "refresh" then TriggerServerEvent("KOTH-Admin:Refresh")
    elseif a == "info" then TriggerServerEvent("KOTH-Admin:PlayerInfo", data.target)
    elseif a == "bans" then TriggerServerEvent("KOTH-Admin:Bans")
    elseif a == "report" then TriggerServerEvent("KOTH-Admin:Report", data.id, data.what)
    elseif a == "self" then ToggleSelf(data.what)
    else TriggerServerEvent("KOTH-Admin:Action", a, data.target, data.args or {})
    end
    cb({ self = { noclip = noclip, invisible = invisible, god = god, spectating = spectating ~= nil }, staffMode = staffMode })
end)

-- ---------- staff mode / self tools ----------
RegisterNetEvent("KOTH-Admin:StaffMode")
AddEventHandler("KOTH-Admin:StaffMode", function(on)
    staffMode = on
    if not on then
        noclip, invisible, god = false, false, false
        local ped = PlayerPedId()
        SetEntityVisible(ped, true, false)
        SetEntityInvincible(ped, false)
        SetEntityCollision(ped, true, true)
        FreezeEntityPosition(ped, false)
        if spectating then StopSpectate() end
    end
    Plus.Send("admin", "staffmode", { on = on })
    TriggerEvent("KOTH-Plus:Notify", "Staff mode " .. (on and "ON" or "OFF"), on and "success" or "info")
end)

function ToggleSelf(what)
    if not staffMode then
        TriggerEvent("KOTH-Plus:Notify", "Turn staff mode on first.", "error")
        return
    end
    local ped = PlayerPedId()
    if what == "noclip" then
        noclip = not noclip
        SetEntityCollision(ped, not noclip, not noclip)
        FreezeEntityPosition(ped, noclip)
        SetEntityVisible(ped, not noclip and not invisible, false)
    elseif what == "invisible" then
        invisible = not invisible
        SetEntityVisible(ped, not invisible, false)
    elseif what == "god" then
        god = not god
        SetEntityInvincible(ped, god)
    end
end

-- noclip movement (W/S forward/back, A/D strafe, Space/Ctrl up/down, Shift faster)
Citizen.CreateThread(function()
    while true do
        if noclip then
            Wait(0)
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local rot = GetGameplayCamRot(2)
            local rz = math.rad(rot.z)
            local fwd = vector3(-math.sin(rz), math.cos(rz), 0.0)
            local right = vector3(math.cos(rz), math.sin(rz), 0.0)
            local speed = IsControlPressed(0, 21) and 2.5 or 0.6
            local move = vector3(0.0, 0.0, 0.0)
            if IsControlPressed(0, 32) then move = move + fwd end
            if IsControlPressed(0, 33) then move = move - fwd end
            if IsControlPressed(0, 34) then move = move - right end
            if IsControlPressed(0, 35) then move = move + right end
            if IsControlPressed(0, 22) then move = move + vector3(0.0, 0.0, 1.0) end
            if IsControlPressed(0, 36) then move = move - vector3(0.0, 0.0, 1.0) end
            local np = pos + move * speed
            SetEntityCoordsNoOffset(ped, np.x, np.y, np.z, true, true, true)
            SetEntityHeading(ped, rot.z)
        else
            Wait(250)
        end
    end
end)

-- ---------- actions received from the server ----------
RegisterNetEvent("KOTH-Admin:Teleport")
AddEventHandler("KOTH-Admin:Teleport", function(c)
    if not c then return end
    local ped = PlayerPedId()
    RequestCollisionAtCoord(c.x, c.y, c.z)
    SetEntityCoords(ped, c.x + 1.0, c.y + 1.0, c.z, false, false, false, false)
end)

RegisterNetEvent("KOTH-Admin:Freeze")
AddEventHandler("KOTH-Admin:Freeze", function()
    frozen = not frozen
    FreezeEntityPosition(PlayerPedId(), frozen)
    TriggerEvent("KOTH-Plus:Notify", frozen and "You were frozen by staff." or "You were unfrozen.", frozen and "error" or "info")
end)

RegisterNetEvent("KOTH-Admin:Slay")
AddEventHandler("KOTH-Admin:Slay", function()
    SetEntityHealth(PlayerPedId(), 0)
end)

function StopSpectate()
    local ped = PlayerPedId()
    NetworkSetInSpectatorMode(false, ped)
    if spectating and spectating.pos then
        SetEntityCoords(ped, spectating.pos.x, spectating.pos.y, spectating.pos.z, false, false, false, false)
    end
    FreezeEntityPosition(ped, false)
    SetEntityCollision(ped, true, true)
    SetEntityVisible(ped, not invisible, false)
    spectating = nil
end

RegisterNetEvent("KOTH-Admin:Spectate")
AddEventHandler("KOTH-Admin:Spectate", function(target, coords)
    if spectating then return StopSpectate() end
    local ped = PlayerPedId()
    spectating = { target = target, pos = GetEntityCoords(ped) }
    SetEntityVisible(ped, false, false)
    SetEntityCollision(ped, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityCoords(ped, coords.x, coords.y, coords.z - 15.0, false, false, false, false)
    Citizen.CreateThread(function()
        local tries = 0
        while tries < 40 do
            local p = GetPlayerFromServerId(target)
            if p ~= -1 and DoesEntityExist(GetPlayerPed(p)) then
                NetworkSetInSpectatorMode(true, GetPlayerPed(p))
                TriggerEvent("KOTH-Plus:Notify", "Spectating " .. GetPlayerName(p) .. " (press Spectate again to stop)", "info")
                return
            end
            tries = tries + 1
            Wait(100)
        end
        TriggerEvent("KOTH-Plus:Notify", "Player is too far away to spectate.", "error")
        StopSpectate()
    end)
end)
