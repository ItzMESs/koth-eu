-- Shared client helpers for koth-plus

Plus = { panel = nil }    -- name of the panel that currently has NUI focus

function Plus.Open(panel, data)
    Plus.panel = panel
    SendNUIMessage({ app = panel, action = "open", data = data })
    SetNuiFocus(true, true)
end

function Plus.Send(app, action, data)
    SendNUIMessage({ app = app, action = action, data = data })
end

function Plus.Close()
    Plus.panel = nil
    SetNuiFocus(false, false)
end

RegisterNUICallback("close", function(_, cb)
    Plus.Close()
    cb("ok")
end)

-- small toast in the corner
RegisterNetEvent("KOTH-Plus:Notify")
AddEventHandler("KOTH-Plus:Notify", function(msg, kind)
    Plus.Send("toast", "show", { text = msg, kind = kind or "info" })
end)

-- staff announcement for everyone
RegisterNetEvent("KOTH-Plus:Announce")
AddEventHandler("KOTH-Plus:Announce", function(text, by)
    Plus.Send("announce", "show", { text = text, by = by })
    PlaySoundFrontend(-1, "CHECKPOINT_PERFECT", "HUD_MINI_GAME_SOUNDSET", true)
end)

-- ask the server for our stats / killstreak state
local function ready() TriggerServerEvent("KOTH-Plus:Ready") end
AddEventHandler("playerSpawned", ready)
Citizen.CreateThread(function() Wait(4000) ready() end)

AddEventHandler("onResourceStop", function(res)
    if res == GetCurrentResourceName() and Plus.panel then SetNuiFocus(false, false) end
end)

-- helpers
function Plus.RayFromCamera(distance)
    local rot = GetGameplayCamRot(2)
    local cam = GetGameplayCamCoord()
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local dir = vector3(-math.sin(rz) * math.abs(math.cos(rx)), math.cos(rz) * math.abs(math.cos(rx)), math.sin(rx))
    local dest = cam + dir * distance
    local ray = StartShapeTestRay(cam.x, cam.y, cam.z, dest.x, dest.y, dest.z, -1, PlayerPedId(), 0)
    local _, hit, coords = GetShapeTestResult(ray)
    if hit == 1 then return coords end
    return nil
end

function Plus.DrawText3D(x, y, z, text, r, g, b)
    local on, sx, sy = World3dToScreen2d(x, y, z)
    if not on then return end
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextColour(r or 255, g or 255, b or 255, 230)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
end
