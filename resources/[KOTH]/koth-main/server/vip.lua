-- ============================================================
--  KOTH VIP (server side). Menu/UI: koth-vip resource.
--  A player is VIP when `player.type = 'vip'` in the database.
--  Give / remove VIP from the server console (or with the
--  ace permission command.setvip):
--      setvip <server id> 1     -> VIP
--      setvip <server id> 0     -> normal player
-- ============================================================

VIP_BOOST = 1.5          -- XP and money multiplier for VIPs
VIP_TEAM_BYPASS = true   -- VIPs can join a team even when it is "full"

VIP_PERKS = {
    { icon = "fa-angle-double-up", title = "x1.5 XP & money",       text = "Every kill, assist and capture pays 50% more." },
    { icon = "fa-users",           title = "Join full teams",       text = "Bypass team auto-balancing." },
    { icon = "fa-crosshairs",      title = "Free weapon attachments", text = "Scopes, grips, suppressors, clips and tints." },
    { icon = "fa-car",             title = "Vehicle paint",          text = "Primary and secondary colour for your vehicle." },
    { icon = "fa-crown",           title = "VIP badge",              text = "Gold badge next to your name on the scoreboard." },
}

local VipPlayers = {}

function IsVip(src)
    return VipPlayers[tonumber(src)] == true
end

local function sendStatus(src)
    TriggerClientEvent("KOTH-VIP:Status", src, IsVip(src), VIP_PERKS, VIP_BOOST)
end

local function loadVip(src)
    local identifier = GetIdentifierFromId(src)
    if not identifier then return end
    MySQL.Async.fetchAll('SELECT type FROM player WHERE license1 = @identifier', {
        ['@identifier'] = identifier
    }, function(result)
        VipPlayers[src] = (result and result[1] and result[1].type == 'vip') or false
        sendStatus(src)
    end)
end

RegisterNetEvent("KOTH-VIP:Request")
AddEventHandler("KOTH-VIP:Request", function()
    loadVip(source)
end)

AddEventHandler("playerDropped", function()
    VipPlayers[source] = nil
end)

-- keep the scoreboard flag in sync (PlayerDataInfo is in server.lua)
Citizen.CreateThread(function()
    while true do
        Wait(3000)
        if PlayerDataInfo then
            for _, p in pairs(PlayerDataInfo) do
                p.vip = IsVip(p.id)
            end
        end
    end
end)

local function reply(src, msg)
    if src == 0 then
        print("[VIP] " .. msg)
    else
        TriggerClientEvent("chat:addMessage", src, { args = { "^3VIP", msg } })
    end
end

-- Give / remove VIP (used by the command below and the admin panel)
function SetVip(staff, target, on)
    local identifier = GetIdentifierFromId(target)
    if not identifier then
        return reply(staff, "Player has no license identifier.")
    end
    MySQL.Async.execute('UPDATE player SET type = @type WHERE license1 = @identifier', {
        ['@type'] = on and 'vip' or 'player',
        ['@identifier'] = identifier
    }, function()
        VipPlayers[target] = on
        sendStatus(target)
        reply(staff, GetPlayerName(target) .. (on and " is now VIP." or " is no longer VIP."))
        TriggerClientEvent("chat:addMessage", target, { args = { "^3VIP", on and "You are now VIP! Press F5 to open the VIP menu." or "Your VIP status was removed." } })
        TriggerEvent("SendLogs", "``VIP " .. (on and "added" or "removed") .. " : [" .. target .. "] " .. GetPlayerName(target) .. "``", "staffmod")
    end)
end

RegisterCommand("setvip", function(source, args)
    local target = tonumber(args[1])
    local on = args[2] ~= "0"
    if not target or not GetPlayerName(target) then
        return reply(source, "Usage: setvip <server id> <1|0>")
    end
    SetVip(source, target, on)
end, true) -- restricted: console or ace "command.setvip"
