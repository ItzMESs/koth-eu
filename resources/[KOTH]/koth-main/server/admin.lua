-- ============================================================
--  KOTH admin panel + reports (server side). UI: koth-plus.
--  Staff = Admin.Whitlist in ConfigAdmin.lua, or ACE:
--     add_ace identifier.license:xxxx koth.founder allow
--     add_ace identifier.license:xxxx koth.admin allow
--     add_ace identifier.license:xxxx koth.mod allow
-- ============================================================

local RANK_LABEL = { [1] = "Moderator", [2] = "Admin", [3] = "Founder" }

-- minimum rank for each action
local PERM = {
    staffmode = 1, ["goto"] = 1, bring = 1, spectate = 1, freeze = 1, revive = 1, slay = 1, kick = 1,
    reports = 1, announce = 1, ban = 2, unban = 2, money = 3, vip = 3, mapvote = 2,
}

local REPORT_COOLDOWN = 60    -- seconds between reports per player
local REPORT_REASONS = { Cheating = true, Teamkill = true, Toxic = true, ["Base camping"] = true, ["Bug abuse"] = true, Other = true }

local Reports = {}            -- open reports in memory: list of { id, ... }
local lastReport = {}
local StaffOn = {}            -- [src] = true when staff mode is on

local function license(src)
    for _, v in pairs(GetPlayerIdentifiers(src)) do
        if string.sub(v, 1, 8) == "license:" then return v end
    end
end

function GetStaffRank(src)
    src = tonumber(src)
    if not src then return 0 end
    if src == 0 then return 3 end -- console
    local l = license(src)
    local r = l and Admin and Admin.Whitlist and Admin.Whitlist[l]
    if r then return tonumber(r) or 1 end
    if IsPlayerAceAllowed(src, "koth.founder") then return 3 end
    if IsPlayerAceAllowed(src, "koth.admin") then return 2 end
    if IsPlayerAceAllowed(src, "koth.mod") then return 1 end
    return 0
end

local function can(src, action)
    return GetStaffRank(src) >= (PERM[action] or 3)
end

local function log(src, msg)
    print(("[ADMIN] %s: %s"):format(GetPlayerName(src) or "console", msg))
    TriggerEvent("SendLogs", ("``[ADMIN] %s : %s``"):format(GetPlayerName(src) or "console", msg), "admin")
end

local function notify(src, msg, kind)
    TriggerClientEvent("KOTH-Plus:Notify", src, msg, kind or "info")
end

local function teamOf(src)
    for _, t in pairs(TeamIDPlayer or {}) do if t.id == src then return t.team end end
end

local function staffOnline()
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        if GetStaffRank(id) > 0 then list[#list + 1] = id end
    end
    return list
end

local function playersList()
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        local reports = 0
        for _, r in ipairs(Reports) do if r.targetId == id and r.status == "open" then reports = reports + 1 end end
        list[#list + 1] = {
            id = id, name = GetPlayerName(id), ping = GetPlayerPing(id), team = teamOf(id),
            vip = IsVip and IsVip(id) or false, prestige = GetPrestige and GetPrestige(id) or 0,
            staff = GetStaffRank(id), reports = reports,
        }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

local function openReports()
    local out = {}
    for _, r in ipairs(Reports) do if r.status ~= "closed" then out[#out + 1] = r end end
    return out
end

-- ---------- open panel ----------
RegisterNetEvent("KOTH-Admin:Open")
AddEventHandler("KOTH-Admin:Open", function()
    local src = source
    local rank = GetStaffRank(src)
    if rank < 1 then return notify(src, "You are not staff.", "error") end
    local perms = {}
    for k, v in pairs(PERM) do perms[k] = rank >= v end
    TriggerClientEvent("KOTH-Admin:Data", src, {
        rank = rank, rankLabel = RANK_LABEL[rank], perms = perms, staffMode = StaffOn[src] or false,
        players = playersList(), reports = openReports(), maxPlayers = GetConvarInt("sv_maxclients", 64),
    })
end)

RegisterNetEvent("KOTH-Admin:Refresh")
AddEventHandler("KOTH-Admin:Refresh", function()
    local src = source
    if GetStaffRank(src) < 1 then return end
    TriggerClientEvent("KOTH-Admin:Players", src, playersList(), openReports())
end)

-- details of one player
RegisterNetEvent("KOTH-Admin:PlayerInfo")
AddEventHandler("KOTH-Admin:PlayerInfo", function(target)
    local src = source
    target = tonumber(target)
    if GetStaffRank(src) < 1 or not target or not GetPlayerName(target) then return end
    local l = license(target)
    MySQL.Async.fetchAll('SELECT money, exp FROM player WHERE license1 = @l', { ['@l'] = l }, function(pl)
        MySQL.Async.fetchAll('SELECT kills, deaths, playtime, prestige FROM player_stats WHERE license = @l', { ['@l'] = l }, function(st)
            local s = st and st[1] or {}
            local exp = pl and pl[1] and tonumber(pl[1].exp) or 0
            local reports = 0
            for _, r in ipairs(Reports) do if r.targetId == target and r.status ~= "closed" then reports = reports + 1 end end
            TriggerClientEvent("KOTH-Admin:PlayerInfo", src, {
                id = target, name = GetPlayerName(target), license = l, ping = GetPlayerPing(target), team = teamOf(target),
                money = pl and pl[1] and tonumber(pl[1].money) or 0,
                level = math.floor((595 + (math.sqrt(5) * math.sqrt((584 * exp) + 4500))) / 730),
                kills = tonumber(s.kills) or 0, deaths = tonumber(s.deaths) or 0, playtime = tonumber(s.playtime) or 0,
                prestige = tonumber(s.prestige) or 0, vip = IsVip and IsVip(target) or false, reports = reports,
                frozen = false,
            })
        end)
    end)
end)

-- ---------- actions ----------
local function ban(src, target, hours, reason)
    local l = license(target) or "N/A"
    local token = GetPlayerToken(target, 0) or "N/A"
    local ip = GetPlayerEndpoint(target) or "N/A"
    local permanent = (hours <= 0) and 1 or 0
    local now = os.time()
    local exp = now + math.max(hours, 0) * 3600
    local targetName, staffName = GetPlayerName(target), GetPlayerName(src) or "console"
    local params = { ['@l'] = l, ['@t'] = token, ['@ip'] = ip, ['@tn'] = targetName, ['@sn'] = staffName, ['@r'] = reason, ['@at'] = now, ['@ex'] = exp, ['@p'] = permanent }
    MySQL.Async.execute('INSERT INTO banlist (licenseid, token, playerip, targetName, sourceName, reason, timeat, expiration, permanent) VALUES (@l, @t, @ip, @tn, @sn, @r, @at, @ex, @p)', params)
    MySQL.Async.execute('INSERT INTO banlisthistory (licenseid, token, playerip, targetName, sourceName, reason, timeat, expiration, permanent) VALUES (@l, @t, @ip, @tn, @sn, @r, @at, @ex, @p)', params)
    DropPlayer(target, ("You are banned.\nReason: %s\nDuration: %s\nBy: %s"):format(reason, permanent == 1 and "Permanent" or (hours .. "h"), staffName))
    log(src, ("banned %s (%s) for %s: %s"):format(targetName, l, permanent == 1 and "permanent" or (hours .. "h"), reason))
end

RegisterNetEvent("KOTH-Admin:Action")
AddEventHandler("KOTH-Admin:Action", function(action, target, args)
    local src = source
    args = type(args) == "table" and args or {}
    if not can(src, action) then return notify(src, "You do not have permission for that.", "error") end
    target = tonumber(target)
    local needsTarget = action ~= "staffmode" and action ~= "announce" and action ~= "unban" and action ~= "mapvote"
    if needsTarget and (not target or not GetPlayerName(target)) then return notify(src, "Player is not online.", "error") end

    if action == "staffmode" then
        StaffOn[src] = not StaffOn[src]
        TriggerClientEvent("KOTH-Admin:StaffMode", src, StaffOn[src])
        log(src, "staff mode " .. (StaffOn[src] and "ON" or "OFF"))
        return
    end

    if action == "goto" then
        TriggerClientEvent("KOTH-Admin:Teleport", src, GetEntityCoords(GetPlayerPed(target)))
    elseif action == "bring" then
        TriggerClientEvent("KOTH-Admin:Teleport", target, GetEntityCoords(GetPlayerPed(src)))
    elseif action == "spectate" then
        if not StaffOn[src] then return notify(src, "Turn staff mode on first.", "error") end
        TriggerClientEvent("KOTH-Admin:Spectate", src, target, GetEntityCoords(GetPlayerPed(target)))
    elseif action == "freeze" then
        TriggerClientEvent("KOTH-Admin:Freeze", target)
    elseif action == "revive" then
        TriggerClientEvent("core:ResetDeathStatus", target, true)
    elseif action == "slay" then
        TriggerClientEvent("KOTH-Admin:Slay", target)
    elseif action == "kick" then
        local reason = tostring(args.reason or "Kicked by staff")
        DropPlayer(target, "Kicked: " .. reason)
    elseif action == "ban" then
        local hours = tonumber(args.hours) or 0
        ban(src, target, hours, tostring(args.reason or "No reason"))
    elseif action == "money" then
        local amount = math.floor(tonumber(args.amount) or 0)
        if amount <= 0 or amount > 1000000 then return notify(src, "Invalid amount.", "error") end
        AddMoneyServer(target, amount, true)
        notify(target, ("You received $%s from staff."):format(amount), "success")
    elseif action == "vip" then
        if SetVip then SetVip(src, target, not (IsVip and IsVip(target))) end
    elseif action == "announce" then
        local text = tostring(args.text or ""):sub(1, 200)
        if text == "" then return end
        TriggerClientEvent("KOTH-Plus:Announce", -1, text, GetPlayerName(src))
    elseif action == "mapvote" then
        if MapVoteStart then MapVoteStart() end
    elseif action == "unban" then
        MySQL.Async.execute('DELETE FROM banlist WHERE licenseid = @l', { ['@l'] = tostring(args.license or "") })
        notify(src, "Player unbanned.", "success")
    end

    if action ~= "announce" then
        log(src, ("%s -> %s %s"):format(action, target and GetPlayerName(target) or "", args.reason and ("(" .. tostring(args.reason) .. ")") or ""))
    else
        log(src, "announce: " .. tostring(args.text))
    end
    if action ~= "spectate" and action ~= "goto" then notify(src, "Done: " .. action, "success") end
end)

-- bans list
RegisterNetEvent("KOTH-Admin:Bans")
AddEventHandler("KOTH-Admin:Bans", function()
    local src = source
    if GetStaffRank(src) < 1 then return end
    MySQL.Async.fetchAll('SELECT licenseid, targetName, sourceName, reason, timeat, expiration, permanent FROM banlist ORDER BY timeat DESC LIMIT 50', {}, function(r)
        TriggerClientEvent("KOTH-Admin:Bans", src, r or {}, os.time())
    end)
end)

-- ---------- reports ----------
RegisterNetEvent("KOTH-Report:Open")
AddEventHandler("KOTH-Report:Open", function()
    local src = source
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        if id ~= src then list[#list + 1] = { id = id, name = GetPlayerName(id), team = teamOf(id) } end
    end
    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
    local lk = LastKiller and LastKiller[src]
    TriggerClientEvent("KOTH-Report:Data", src, {
        players = list,
        lastKiller = (lk and GetPlayerName(lk.id)) and { id = lk.id, ago = os.time() - lk.time } or nil,
        staff = #staffOnline(),
        cooldown = math.max(0, REPORT_COOLDOWN - (os.time() - (lastReport[src] or 0))),
    })
end)

RegisterNetEvent("KOTH-Report:Submit")
AddEventHandler("KOTH-Report:Submit", function(target, reason, details)
    local src = source
    target = tonumber(target)
    if os.time() - (lastReport[src] or 0) < REPORT_COOLDOWN then
        return notify(src, "Please wait before sending another report.", "error")
    end
    if not target or not GetPlayerName(target) or target == src then return notify(src, "Pick a player to report.", "error") end
    if not REPORT_REASONS[reason] then reason = "Other" end
    details = tostring(details or ""):sub(1, 400)
    lastReport[src] = os.time()

    local r = {
        id = 0, reporterId = src, reporter = GetPlayerName(src), targetId = target, target = GetPlayerName(target),
        reason = reason, details = details, time = os.time(), status = "open", claimedBy = nil,
    }
    MySQL.Async.insert('INSERT INTO reports (reporter_license, reporter_name, target_license, target_name, reason, details, created) VALUES (@rl, @rn, @tl, @tn, @r, @d, @c)', {
        ['@rl'] = license(src), ['@rn'] = r.reporter, ['@tl'] = license(target), ['@tn'] = r.target, ['@r'] = reason, ['@d'] = details, ['@c'] = r.time,
    }, function(id)
        r.id = id or (#Reports + 1)
        table.insert(Reports, r)
        notify(src, "Report sent. Thank you!", "success")
        for _, s in ipairs(staffOnline()) do TriggerClientEvent("KOTH-Admin:NewReport", s, r) end
        TriggerEvent("SendLogs", ("**Report #%d** %s reported %s for %s: %s"):format(r.id, r.reporter, r.target, reason, details), "report")
    end)
end)

RegisterNetEvent("KOTH-Admin:Report")
AddEventHandler("KOTH-Admin:Report", function(id, what)
    local src = source
    if not can(src, "reports") then return end
    for _, r in ipairs(Reports) do
        if r.id == id then
            if what == "claim" then
                r.status, r.claimedBy = "claimed", GetPlayerName(src)
                if GetPlayerName(r.reporterId) then notify(r.reporterId, ("%s is handling your report."):format(GetPlayerName(src)), "info") end
            elseif what == "close" then
                r.status = "closed"
            elseif what == "goto" and GetPlayerName(r.targetId) then
                TriggerClientEvent("KOTH-Admin:Teleport", src, GetEntityCoords(GetPlayerPed(r.targetId)))
            end
            MySQL.Async.execute('UPDATE reports SET status = @s, handled_by = @h WHERE id = @id', { ['@s'] = r.status, ['@h'] = GetPlayerName(src), ['@id'] = id })
            log(src, ("report #%d %s"):format(id, what))
        end
    end
    TriggerClientEvent("KOTH-Admin:Players", src, playersList(), openReports())
end)

AddEventHandler("playerDropped", function()
    StaffOn[source] = nil
    lastReport[source] = nil
end)
