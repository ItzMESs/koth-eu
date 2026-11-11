-- Cosmetics shop (F6 or /cosmetics). Server: koth-main/server/cosmetics.lua

local state = nil

RegisterNetEvent("KOTH-Cosmetics:State")
AddEventHandler("KOTH-Cosmetics:State", function(s)
    state = s
    Plus.Send("cosmetics", "state", s)
end)

RegisterCommand("cosmetics", function()
    if not state then
        TriggerServerEvent("KOTH-Plus:Ready")
        return TriggerEvent("KOTH-Plus:Notify", "Loading cosmetics, try again in a second.", "info")
    end
    Plus.Open("cosmetics", state)
end, false)
RegisterKeyMapping("cosmetics", "Open cosmetics shop", "keyboard", "F6")

RegisterNUICallback("cosBuy", function(data, cb)
    TriggerServerEvent("KOTH-Cosmetics:Buy", data.key)
    cb("ok")
end)

RegisterNUICallback("cosEquip", function(data, cb)
    TriggerServerEvent("KOTH-Cosmetics:Equip", data.key)
    cb("ok")
end)

-- keep the equipped hat on (team outfits / respawn reset props)
Citizen.CreateThread(function()
    local hadHat = false
    while true do
        Wait(1500)
        local ped = PlayerPedId()
        local h = state and state.hatProp
        if h and not IsEntityDead(ped) then
            if GetPedPropIndex(ped, 0) ~= h.drawable or GetPedPropTextureIndex(ped, 0) ~= h.texture then
                SetPedPropIndex(ped, 0, h.drawable, h.texture, true)
            end
            hadHat = true
        elseif hadHat and not h then
            ClearPedProp(ped, 0)
            hadHat = false
        end
    end
end)
