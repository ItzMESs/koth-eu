-- ============================================================
--  KOTH all-time statistics, bounty, killstreaks and prestige
--  UI: koth-plus resource.  Tables are created automatically
--  (see also sql/koth_update.sql).
-- ============================================================

-- ---------- settings ----------
BOUNTY_MIN_STREAK   = 5      -- kills without dying before a bounty is placed
BOUNTY_BASE         = 750    -- bounty at BOUNTY_MIN_STREAK kills
BOUNTY_PER_KILL     = 250    -- added for every extra kill
BOUNTY_CLAIM_XP     = 300
BOUNTY_ANNOUNCE_AT  = { [5] = true, [8] = true, [10] = true, [15] = true, [20] = true, [25] = true }

PRESTIGE_LEVEL      = 100    -- level needed to prestige
PRESTIGE_MAX        = 10
PRESTIGE_XP_BONUS   = 0.05   -- +5% XP per prestige
PRESTIGE_MONEY      = 25000

KILLSTREAKS = {
    { id = "uav",       label = "UAV",              kills = 3,  icon = "fa-satellite-dish", text = "Shows all enemies on your team's map for 30 seconds." },
    { id = "supply",    label = "Supply drop",      kills = 4,  icon = "fa-medkit",         text = "Full health and a big ammo refill." },
    { id = "airstrike", label = "Airstrike",        kills = 6,  icon = "fa-bomb",           text = "Aim at a spot: 3 explosions hit it after 5 seconds." },
    { id = "precision", label = "Precision strike", kills = 7,  icon = "fa-crosshairs",     text = "One heavy missile on the spot you aim at." },
    { id = "cluster",   label = "Cluster strike",   kills = 10, icon = "fa-fire",           text = "6 explosions over a wide area.", prestige = 2 },
}
KILLSTREAK_SLOTS = 3
KILLSTREAK_DEFAULT = { "uav", "supply", "airstrike" }

-- ---------- state ----------
local P = {}            -- [src] = { license, name, joined, prestige, ks = {}, d = {deltas}, w = {weapon deltas} }
local Streak = {}       -- [src] = kills without dying
local UsedKs = {}       -- [src][id] = true (this life)
local Bounty = {}       -- [src] = amount
local LastDeath = {}    -- [src] = GetGameTimer() of the last counted death
LastKiller = {}         -- [victim] = { id, name, time }  (used by /report)

local KS = {}
for _, k in ipairs(KILLSTREAKS) do KS[k.id] = k end

local function db() return MySQL and MySQL.Async end

-- ---------- tables ----------
Citizen.CreateThread(function()
    Wait(1000)
    MySQL.Async.execute([[CREATE TABLE IF NOT EXISTS `player_stats` (
        `license` varchar(64) NOT NULL,
        `name` varchar(64) DEFAULT NULL,
        `kills` int(11) NOT NULL DEFAULT 0,
        `deaths` int(11) NOT NULL DEFAULT 0,
        `assists` int(11) NOT NULL DEFAULT 0,
        `headshots` int(11) NOT NULL DEFAULT 0,
        `matches` int(11) NOT NULL DEFAULT 0,
        `wins` int(11) NOT NULL DEFAULT 0,
        `playtime` int(11) NOT NULL DEFAULT 0,
        `best_streak` int(11) NOT NULL DEFAULT 0,
        `bounties` int(11) NOT NULL DEFAULT 0,
        `prestige` int(11) NOT NULL DEFAULT 0,
        `killstreaks` varchar(128) DEFAULT NULL,
        `created` int(11) NOT NULL DEFAULT 0,
        PRIMARY KEY (`license`),
        KEY `kills` (`kills`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]], {})
    MySQL.Async.execute([[CREATE TABLE IF NOT EXISTS `player_weapon_kills` (
        `license` varchar(64) NOT NULL,
        `weapon` varchar(64) NOT NULL,
        `kills` int(11) NOT NULL DEFAULT 0,
        PRIMARY KEY (`license`, `weapon`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]], {})
    MySQL.Async.execute([[CREATE TABLE IF NOT EXISTS `reports` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `reporter_license` varchar(64) DEFAULT NULL,
        `reporter_name` varchar(64) DEFAULT NULL,
        `target_license` varchar(64) DEFAULT NULL,
        `target_name` varchar(64) DEFAULT NULL,
        `reason` varchar(32) DEFAULT NULL,
        `details` text DEFAULT NULL,
        `status` varchar(16) NOT NULL DEFAULT 'open',
        `handled_by` varchar(64) DEFAULT NULL,
        `created` int(11) NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]], {})
end)

-- ---------- players ----------
local function newDeltas()
    return { kills = 0, deaths = 0, assists = 0, headshots = 0, matches = 0, wins = 0, playtime = 0, bounties = 0 }
end

function StatsGetPlayer(src) return P[tonumber(src)] end
function GetPrestige(src) local p = P[tonumber(src)]; return p and p.prestige or 0 end
function PrestigeXpMultiplier(src) return 1 + GetPrestige(src) * PRESTIGE_XP_BONUS end
function GetStreak(src) return Streak[tonumber(src)] or 0 end

local function sendState(src)
    local p = P[src]
    if not p then return end
    TriggerClientEvent("KOTH-Plus:State", src, {
        prestige = p.prestige,
        streak = Streak[src] or 0,
        used = UsedKs[src] or {},
        killstreaks = KILLSTREAKS,
        selected = p.ks,
        slots = KILLSTREAK_SLOTS,
    })
end

local function loadPlayer(src)
    local license = GetIdentifierFromId(src)
    if not license then return end
    local name = GetPlayerName(src)
    P[src] = P[src] or { license = license, name = name, joined = os.time(), prestige = 0, ks = KILLSTREAK_DEFAULT, d = newDeltas(), w = {} }
    MySQL.Async.execute('INSERT IGNORE INTO player_stats (license, name, created) VALUES (@l, @n, @t)',
        { ['@l'] = license, ['@n'] = name, ['@t'] = os.time() }, function()
        MySQL.Async.fetchAll('SELECT prestige, killstreaks FROM player_stats WHERE license = @l', { ['@l'] = license }, function(r)
            if not P[src] then return end
            if r and r[1] then
                P[src].prestige = tonumber(r[1].prestige) or 0
                if r[1].killstreaks and r[1].killstreaks ~= "" then
                    local list = {}
                    for id in string.gmatch(r[1].killstreaks, "[^,]+") do
                        if KS[id] then list[#list + 1] = id end
                    end
                    if #list > 0 then P[src].ks = list end
                end
            end
            sendState(src)
        end)
    end)
end

RegisterNetEvent("KOTH-Plus:Ready")
AddEventHandler("KOTH-Plus:Ready", function()
    local src = source
    if not P[src] then loadPlayer(src) else sendState(src) end
end)

local function flush(src)
    local p = P[src]
    if not p then return end
    local now = os.time()
    p.d.playtime = p.d.playtime + (now - p.joined)
    p.joined = now
    local d = p.d
    p.d = newDeltas()
    MySQL.Async.execute([[INSERT INTO player_stats (license, name, kills, deaths, assists, headshots, matches, wins, playtime, bounties, best_streak, created)
        VALUES (@l, @n, @k, @de, @a, @h, @m, @wi, @pt, @b, @bs, @t)
        ON DUPLICATE KEY UPDATE name = VALUES(name), kills = kills + VALUES(kills), deaths = deaths + VALUES(deaths),
        assists = assists + VALUES(assists), headshots = headshots + VALUES(headshots), matches = matches + VALUES(matches),
        wins = wins + VALUES(wins), playtime = playtime + VALUES(playtime), bounties = bounties + VALUES(bounties),
        best_streak = GREATEST(best_streak, VALUES(best_streak))]], {
        ['@l'] = p.license, ['@n'] = p.name, ['@k'] = d.kills, ['@de'] = d.deaths, ['@a'] = d.assists, ['@h'] = d.headshots,
        ['@m'] = d.matches, ['@wi'] = d.wins, ['@pt'] = d.playtime, ['@b'] = d.bounties, ['@bs'] = p.best or 0, ['@t'] = now,
    })
    for weapon, n in pairs(p.w) do
        MySQL.Async.execute('INSERT INTO player_weapon_kills (license, weapon, kills) VALUES (@l, @w, @k) ON DUPLICATE KEY UPDATE kills = kills + VALUES(kills)',
            { ['@l'] = p.license, ['@w'] = weapon, ['@k'] = n })
    end
    p.w = {}
end
StatsFlush = flush

Citizen.CreateThread(function()
    while true do
        Wait(60000)
        for src in pairs(P) do flush(src) end
    end
end)

local function broadcastBounties()
    local list = {}
    for id, amount in pairs(Bounty) do
        if GetPlayerName(id) then
            local team
            for _, t in pairs(TeamIDPlayer or {}) do if t.id == id then team = t.team end end
            list[#list + 1] = { id = id, name = GetPlayerName(id), amount = amount, streak = Streak[id] or 0, team = team }
        end
    end
    table.sort(list, function(a, b) return a.amount > b.amount end)
    TriggerClientEvent("KOTH-Plus:Bounties", -1, list)
end

AddEventHandler("playerDropped", function()
    local src = source
    flush(src)
    P[src], Streak[src], UsedKs[src], LastDeath[src], LastKiller[src] = nil, nil, nil, nil, nil
    if Bounty[src] then Bounty[src] = nil; broadcastBounties() end
end)

-- ---------- hooks called from secret_server.lua ----------

-- returns false when this death was already counted (duplicate report)
function KothOnDeath(victim, killer)
    local now = GetGameTimer()
    if LastDeath[victim] and now - LastDeath[victim] < 4000 then return false end
    LastDeath[victim] = now

    local p = P[victim]
    if p then p.d.deaths = p.d.deaths + 1 end

    if killer and tonumber(killer) and tonumber(killer) > 0 and GetPlayerName(killer) then
        LastKiller[victim] = { id = tonumber(killer), name = GetPlayerName(killer), time = os.time() }
    end

    -- bounty on the victim is claimed by the killer
    local amount = Bounty[victim]
    if amount then
        Bounty[victim] = nil
        local k = tonumber(killer)
        if k and k > 0 and k ~= victim and GetPlayerName(k) then
            AddMoneyServer(k, amount, true)
            AddXpServer(k, BOUNTY_CLAIM_XP, true)
            if P[k] then P[k].d.bounties = P[k].d.bounties + 1 end
            TriggerClientEvent("KOTH-Plus:BountyClaimed", -1, { killer = GetPlayerName(k), killerId = k, victim = GetPlayerName(victim), amount = amount, xp = BOUNTY_CLAIM_XP })
            TriggerEvent("SendLogs", ("%s claimed the $%d bounty on %s"):format(GetPlayerName(k), amount, GetPlayerName(victim)), "Kill")
        end
        broadcastBounties()
    end

    Streak[victim] = 0
    UsedKs[victim] = {}
    sendState(victim)
    return true
end

function KothOnKill(killer, victim, data)
    killer = tonumber(killer)
    if not killer or killer == victim or not GetPlayerName(killer) then return end
    local p = P[killer]
    if p then
        p.d.kills = p.d.kills + 1
        if data and data.headshot then p.d.headshots = p.d.headshots + 1 end
        local weapon = (WeaponLabel and data and WeaponLabel[data.weaponhash]) or (data and data.killerinveh and "VEHICLE") or "OTHER"
        p.w[weapon] = (p.w[weapon] or 0) + 1
    end

    Streak[killer] = (Streak[killer] or 0) + 1
    local s = Streak[killer]
    if p and s > (p.best or 0) then p.best = s end

    if s >= BOUNTY_MIN_STREAK then
        local amount = BOUNTY_BASE + (s - BOUNTY_MIN_STREAK) * BOUNTY_PER_KILL
        Bounty[killer] = amount
        if BOUNTY_ANNOUNCE_AT[s] then
            TriggerClientEvent("KOTH-Plus:BountyPlaced", -1, { id = killer, name = GetPlayerName(killer), amount = amount, streak = s })
        end
        broadcastBounties()
    end
    sendState(killer)
end

function KothOnAssist(src)
    local p = P[tonumber(src)]
    if p then p.d.assists = p.d.assists + 1 end
end

function StatsMatchEnd(winnerTeam)
    for _, info in pairs(PlayerDataInfo or {}) do
        local p = P[info.id]
        if p then
            p.d.matches = p.d.matches + 1
            for _, t in pairs(TeamIDPlayer or {}) do
                if t.id == info.id and t.team == winnerTeam then p.d.wins = p.d.wins + 1 end
            end
        end
    end
    for src in pairs(P) do flush(src) end
end

-- ---------- killstreaks ----------
local function teamOf(src)
    for _, t in pairs(TeamIDPlayer or {}) do if t.id == src then return t.team end end
end

RegisterNetEvent("KOTH-Plus:SetKillstreaks")
AddEventHandler("KOTH-Plus:SetKillstreaks", function(list)
    local src = source
    local p = P[src]
    if not p or type(list) ~= "table" then return end
    local out, seen = {}, {}
    for _, id in ipairs(list) do
        local k = KS[id]
        if k and not seen[id] and #out < KILLSTREAK_SLOTS and (k.prestige or 0) <= p.prestige then
            seen[id] = true
            out[#out + 1] = id
        end
    end
    table.sort(out, function(a, b) return KS[a].kills < KS[b].kills end)
    p.ks = out
    MySQL.Async.execute('UPDATE player_stats SET killstreaks = @k WHERE license = @l', { ['@k'] = table.concat(out, ","), ['@l'] = p.license })
    sendState(src)
end)

local function runUav(src)
    local team = teamOf(src)
    local members = {}
    for _, t in pairs(TeamIDPlayer or {}) do if t.team == team then members[#members + 1] = t.id end end
    Citizen.CreateThread(function()
        local untilT = GetGameTimer() + 30000
        while GetGameTimer() < untilT do
            local enemies = {}
            for _, t in pairs(TeamIDPlayer or {}) do
                if t.team ~= team and GetPlayerName(t.id) then
                    local c = GetEntityCoords(GetPlayerPed(t.id))
                    enemies[#enemies + 1] = { id = t.id, x = c.x, y = c.y, z = c.z }
                end
            end
            for _, m in ipairs(members) do TriggerClientEvent("KOTH-Plus:UavPing", m, enemies, GetPlayerName(src)) end
            Wait(2000)
        end
        for _, m in ipairs(members) do TriggerClientEvent("KOTH-Plus:UavPing", m, false) end
    end)
end

RegisterNetEvent("KOTH-Plus:UseKillstreak")
AddEventHandler("KOTH-Plus:UseKillstreak", function(id)
    local src = source
    local p, k = P[src], KS[id]
    if not p or not k then return end
    local selected = false
    for _, s in ipairs(p.ks) do if s == id then selected = true end end
    UsedKs[src] = UsedKs[src] or {}
    if not selected or UsedKs[src][id] or (Streak[src] or 0) < k.kills or (k.prestige or 0) > p.prestige then return end

    UsedKs[src][id] = true
    TriggerEvent("SendLogs", ("%s used killstreak %s (%d kills)"):format(GetPlayerName(src), k.label, Streak[src]), "Kill")
    if id == "uav" then runUav(src) end
    TriggerClientEvent("KOTH-Plus:KillstreakGo", src, id)
    TriggerClientEvent("KOTH-Plus:KillstreakUsed", -1, { by = GetPlayerName(src), label = k.label, team = teamOf(src) })
    sendState(src)
end)

-- ---------- prestige ----------
local function levelFromExp(exp)
    return math.floor((595 + (math.sqrt(5) * math.sqrt((584 * exp) + 4500))) / 730)
end

RegisterNetEvent("KOTH-Plus:Prestige")
AddEventHandler("KOTH-Plus:Prestige", function()
    local src = source
    local p = P[src]
    if not p then return end
    MySQL.Async.fetchAll('SELECT exp FROM player WHERE license1 = @l', { ['@l'] = p.license }, function(r)
        local exp = r and r[1] and tonumber(r[1].exp) or 0
        if levelFromExp(exp) < PRESTIGE_LEVEL then
            return TriggerClientEvent("KOTH-Plus:Notify", src, ("You need level %d to prestige."):format(PRESTIGE_LEVEL), "error")
        end
        if p.prestige >= PRESTIGE_MAX then
            return TriggerClientEvent("KOTH-Plus:Notify", src, "You are already max prestige.", "error")
        end
        p.prestige = p.prestige + 1
        MySQL.Async.execute('UPDATE player SET exp = 0, level = 1 WHERE license1 = @l', { ['@l'] = p.license }, function()
            MySQL.Async.execute('UPDATE player_stats SET prestige = @p WHERE license = @l', { ['@p'] = p.prestige, ['@l'] = p.license })
            AddMoneyServer(src, PRESTIGE_MONEY, true)
            TriggerEvent("KOTH:UpdateHUD2", src)
            TriggerClientEvent("KOTH-Plus:PrestigeDone", src, p.prestige)
            TriggerClientEvent("chat:addMessage", -1, { args = { "^5PRESTIGE", ("%s reached Prestige %d!"):format(GetPlayerName(src), p.prestige) } })
            TriggerEvent("SendLogs", ("%s prestiged to %d"):format(GetPlayerName(src), p.prestige), "admin")
            sendState(src)
        end)
    end)
end)

-- scoreboard flag
Citizen.CreateThread(function()
    while true do
        Wait(3000)
        for _, info in pairs(PlayerDataInfo or {}) do
            info.prestige = GetPrestige(info.id)
        end
    end
end)

-- ---------- career (/stats) ----------
RegisterNetEvent("KOTH-Plus:GetCareer")
AddEventHandler("KOTH-Plus:GetCareer", function()
    local src = source
    local p = P[src]
    if not p then return end
    flush(src)
    Wait(300)
    MySQL.Async.fetchAll('SELECT * FROM player_stats WHERE license = @l', { ['@l'] = p.license }, function(me)
        MySQL.Async.fetchAll('SELECT weapon, kills FROM player_weapon_kills WHERE license = @l ORDER BY kills DESC LIMIT 5', { ['@l'] = p.license }, function(weapons)
            MySQL.Async.fetchAll('SELECT license, name, kills, deaths, prestige FROM player_stats ORDER BY kills DESC LIMIT 10', {}, function(top)
                local mine = me and me[1] or {}
                MySQL.Async.fetchAll('SELECT COUNT(*) AS c FROM player_stats WHERE kills > @k', { ['@k'] = mine.kills or 0 }, function(rank)
                    MySQL.Async.fetchAll('SELECT exp FROM player WHERE license1 = @l', { ['@l'] = p.license }, function(lv)
                        for _, t in ipairs(top or {}) do t.me = (t.license == p.license); t.license = nil end
                        mine.license = nil
                        local exp = lv and lv[1] and tonumber(lv[1].exp) or 0
                        TriggerClientEvent("KOTH-Plus:Career", src, {
                            me = mine,
                            weapons = weapons or {},
                            top = top or {},
                            rank = ((rank and rank[1] and tonumber(rank[1].c)) or 0) + 1,
                            level = levelFromExp(exp),
                            prestige = p.prestige,
                            prestigeLevel = PRESTIGE_LEVEL,
                            prestigeMax = PRESTIGE_MAX,
                            prestigeBonus = PRESTIGE_XP_BONUS,
                            prestigeMoney = PRESTIGE_MONEY,
                            killstreaks = KILLSTREAKS,
                        })
                    end)
                end)
            end)
        end)
    end)
end)

-- resource restart: re-load players already on the server
AddEventHandler("onResourceStart", function(res)
    if res ~= GetCurrentResourceName() then return end
    Citizen.SetTimeout(3000, function()
        for _, id in ipairs(GetPlayers()) do loadPlayer(tonumber(id)) end
    end)
end)
