-- Bounty: banner, board, claim message, skull above the target and map blip

local bounties = {}     -- list from the server
local blips = {}

RegisterNetEvent("KOTH-Plus:Bounties")
AddEventHandler("KOTH-Plus:Bounties", function(list)
    bounties = list or {}
    Plus.Send("bounty", "board", bounties)
end)

RegisterNetEvent("KOTH-Plus:BountyPlaced")
AddEventHandler("KOTH-Plus:BountyPlaced", function(b)
    b.me = (b.id == GetPlayerServerId(PlayerId()))
    Plus.Send("bounty", "placed", b)
    PlaySoundFrontend(-1, "Bed", "WastedSounds", true)
end)

RegisterNetEvent("KOTH-Plus:BountyClaimed")
AddEventHandler("KOTH-Plus:BountyClaimed", function(c)
    c.me = (c.killerId == GetPlayerServerId(PlayerId()))
    Plus.Send("bounty", "claimed", c)
    if c.me then PlaySoundFrontend(-1, "PROPERTY_PURCHASE", "HUD_AWARDS", true) end
end)

-- map blips + 3D skull above bounty targets (when they are streamed in)
Citizen.CreateThread(function()
    while true do
        local me = GetPlayerServerId(PlayerId())
        local active = {}
        local any = false
        for _, b in ipairs(bounties) do
            if b.id ~= me then
                local p = GetPlayerFromServerId(b.id)
                if p ~= -1 then
                    local ped = GetPlayerPed(p)
                    if DoesEntityExist(ped) then
                        any = true
                        active[b.id] = true
                        if not blips[b.id] or not DoesBlipExist(blips[b.id]) then
                            local bl = AddBlipForEntity(ped)
                            SetBlipSprite(bl, 303)
                            SetBlipColour(bl, 47)
                            SetBlipScale(bl, 0.9)
                            BeginTextCommandSetBlipName("STRING")
                            AddTextComponentSubstringPlayerName("Bounty: " .. b.name)
                            EndTextCommandSetBlipName(bl)
                            blips[b.id] = bl
                        end
                        local c = GetEntityCoords(ped)
                        if #(c - GetEntityCoords(PlayerPedId())) < 150.0 and HasEntityClearLosToEntity(PlayerPedId(), ped, 17) then
                            Plus.DrawText3D(c.x, c.y, c.z + 1.25, ("~o~BOUNTY ~g~$%s"):format(b.amount))
                        end
                    end
                end
            end
        end
        for id, bl in pairs(blips) do
            if not active[id] then RemoveBlip(bl); blips[id] = nil end
        end
        Wait(any and 0 or 1000)
    end
end)
