-- KOTH map vote (client). Server logic: koth-main/server/mapvote.lua
local isOpen = false

RegisterNetEvent("KOTH-MapVote:Open")
AddEventHandler("KOTH-MapVote:Open", function(data)
    isOpen = true
    SendNUIMessage({ action = "open", data = data })
    SetNuiFocus(true, true)
end)

RegisterNetEvent("KOTH-MapVote:Update")
AddEventHandler("KOTH-MapVote:Update", function(data)
    SendNUIMessage({ action = "update", data = data })
end)

RegisterNetEvent("KOTH-MapVote:Voted")
AddEventHandler("KOTH-MapVote:Voted", function(index)
    SendNUIMessage({ action = "voted", id = index })
end)

RegisterNetEvent("KOTH-MapVote:Started")
AddEventHandler("KOTH-MapVote:Started", function()
    SendNUIMessage({ action = "banner", kind = "start" })
    PlaySoundFrontend(-1, "CHECKPOINT_PERFECT", "HUD_MINI_GAME_SOUNDSET", true)
end)

RegisterNetEvent("KOTH-MapVote:Result")
AddEventHandler("KOTH-MapVote:Result", function(map)
    SendNUIMessage({ action = "result", map = map })
end)

RegisterNUICallback("vote", function(data, cb)
    TriggerServerEvent("KOTH-MapVote:Vote", tonumber(data.id))
    cb("ok")
end)

RegisterNUICallback("close", function(_, cb)
    isOpen = false
    SetNuiFocus(false, false)
    cb("ok")
end)

AddEventHandler("onResourceStop", function(res)
    if res == GetCurrentResourceName() and isOpen then
        SetNuiFocus(false, false)
    end
end)
