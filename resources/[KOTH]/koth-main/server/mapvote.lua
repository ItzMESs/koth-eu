-- ============================================================
--  KOTH map vote
--  * Starts automatically when any team reaches MAPVOTE_START points.
--  * Players open the vote UI with /mapvote (UI lives in koth-mapvote).
--  * Every map in Configzone.lua is votable.
--  * When the match ends (a team reaches 100) the vote closes and the
--    winning map is written to data/voteinfo.json; InitZone() in
--    server/pos.lua loads it on the next server start.
-- ============================================================

MAPVOTE_START = 80.0

local MapVote = {
    active = false,   -- voting is open
    closed = false,   -- match ended, result decided
    votes = {},       -- [serverId] = map index
    winner = nil,
}

local function mapList()
    local maps = {}
    for i, zone in ipairs(Config) do
        maps[#maps + 1] = { id = i, name = zone.name, votes = 0 }
    end
    for _, idx in pairs(MapVote.votes) do
        if maps[idx] then maps[idx].votes = maps[idx].votes + 1 end
    end
    return maps
end

local function totalVotes()
    local n = 0
    for _ in pairs(MapVote.votes) do n = n + 1 end
    return n
end

local function leadingTeam()
    local best
    for _, t in ipairs(Teams) do
        if not best or t.points > best.points then best = t end
    end
    return best
end

local function payload(src)
    local lead = leadingTeam()
    return {
        maps = mapList(),
        total = totalVotes(),
        players = GetNumPlayerIndices(),
        current = GetZone and GetZone.name or nil,
        myVote = src and MapVote.votes[src] or nil,
        leadTeam = lead and lead.name or nil,
        leadPoints = lead and math.floor(lead.points) or 0,
        active = MapVote.active,
        closed = MapVote.closed,
        winner = MapVote.winner,
    }
end

-- Map with the most votes (ties broken at random). nil when nobody voted.
local function currentWinner()
    local maps = mapList()
    local best, top = 0, {}
    for _, m in ipairs(maps) do
        if m.votes > best then
            best, top = m.votes, { m }
        elseif m.votes == best and best > 0 then
            top[#top + 1] = m
        end
    end
    if best == 0 then return nil end
    return top[math.random(1, #top)].name
end

local function saveResult(name)
    if name then
        SaveResourceFile(GetCurrentResourceName(), "data/voteinfo.json", json.encode({ map = name }), -1)
    end
end

local function broadcast()
    TriggerClientEvent("KOTH-MapVote:Update", -1, payload(nil))
end

local function chat(msg)
    TriggerClientEvent("chat:addMessage", -1, { args = { "^2MapVote", msg } })
end

local function startVote()
    if MapVote.active or MapVote.closed then return end
    MapVote.active = true
    print("^2[MapVote]^7 started")
    TriggerClientEvent("KOTH-MapVote:Started", -1)
    chat("A team reached " .. math.floor(MAPVOTE_START) .. " points! Type ^3/mapvote^7 to vote for the next map.")
end

-- Used by the admin panel.
function MapVoteStart() startVote() end

-- Called from server.lua when the match ends.
function MapVoteFinish()
    if MapVote.closed then return end
    MapVote.active = false
    MapVote.closed = true
    MapVote.winner = currentWinner()
    saveResult(MapVote.winner)
    print("^2[MapVote]^7 finished, next map: " .. tostring(MapVote.winner or "random"))
    TriggerClientEvent("KOTH-MapVote:Result", -1, MapVote.winner)
    broadcast()
    chat("Next map: ^3" .. (MapVote.winner or "random"))
end

-- start check + live updates (leading team points)
Citizen.CreateThread(function()
    while true do
        Wait(2000)
        if not MapVote.active and not MapVote.closed then
            for _, t in ipairs(Teams) do
                if t.points >= MAPVOTE_START then
                    startVote()
                    break
                end
            end
        elseif MapVote.active then
            broadcast()
        end
    end
end)

RegisterCommand("mapvote", function(source)
    local src = source
    if src == 0 then
        print("[MapVote] active=" .. tostring(MapVote.active) .. " votes=" .. totalVotes())
        return
    end
    if not MapVote.active and not MapVote.closed then
        TriggerClientEvent("chat:addMessage", src, { args = { "^2MapVote", "Voting opens when a team reaches " .. math.floor(MAPVOTE_START) .. " points." } })
        return
    end
    TriggerClientEvent("KOTH-MapVote:Open", src, payload(src))
end, false)

RegisterNetEvent("KOTH-MapVote:Vote")
AddEventHandler("KOTH-MapVote:Vote", function(index)
    local src = source
    index = tonumber(index)
    if not MapVote.active or not index or not Config[index] then return end
    MapVote.votes[src] = index
    TriggerClientEvent("KOTH-MapVote:Voted", src, index)
    broadcast()
end)

AddEventHandler("playerDropped", function()
    local src = source
    if MapVote.votes[src] then
        MapVote.votes[src] = nil
        if MapVote.active then broadcast() end
    end
end)

-- console helpers for testing
RegisterCommand("mapvote_start", function(source)
    if source == 0 then startVote() end
end, true)

RegisterCommand("mapvote_end", function(source)
    if source == 0 then MapVoteFinish() end
end, true)
