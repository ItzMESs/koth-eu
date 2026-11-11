-- ============================================================
--  Medic medkits and Support ammo bags dropped on the ground.
--  Only team mates see the green circle and get the effect.
--  The owner is paid when a team mate uses the drop.
-- ============================================================

DROP_LIFETIME = 60          -- seconds a medkit / ammo bag stays on the ground
DROP_REWARD = {
    med  = { money = 100, xp = 100, label = "Healed a team mate" },
    ammo = { money = 75,  xp = 75,  label = "Resupplied a team mate" },
}
DROP_REWARD_COOLDOWN = 15   -- seconds between rewards for the same user on the same drop

local Drops = {}            -- [id] = { id, owner, team, kind, coords, expires }
local nextId = 0
local rewarded = {}         -- ["dropId:user"] = os.time()

local function teamOf(src)
    for _, t in pairs(TeamIDPlayer or {}) do if t.id == src then return t.team end end
end

local function removeDrop(id)
    if Drops[id] then
        Drops[id] = nil
        TriggerClientEvent("KOTH-Gadget:Remove", -1, id)
    end
end

-- kind = "med" (medic) or "ammo" (support). Old clients send no kind -> medkit.
RegisterNetEvent('KOTH:Medic:objCreate')
AddEventHandler('KOTH:Medic:objCreate', function(coords, deleteCD, kind)
    local src = source
    kind = (kind == "ammo") and "ammo" or "med"
    local team = teamOf(src)
    if not team or type(coords) ~= "vector3" and type(coords) ~= "table" then return end

    -- one drop of each kind per player: replace the previous one
    for id, d in pairs(Drops) do
        if d.owner == src and d.kind == kind then removeDrop(id) end
    end

    nextId = nextId + 1
    local d = {
        id = nextId, owner = src, ownerName = GetPlayerName(src), team = team, kind = kind,
        coords = { x = coords.x, y = coords.y, z = coords.z }, expires = os.time() + DROP_LIFETIME,
    }
    Drops[d.id] = d
    TriggerClientEvent("KOTH-Gadget:Add", -1, d)
    Citizen.SetTimeout(DROP_LIFETIME * 1000, function()
        if Drops[d.id] and Drops[d.id].expires <= os.time() then removeDrop(d.id) end
    end)
end)

-- a team mate got healed / resupplied by a drop
RegisterNetEvent("KOTH-Gadget:Used")
AddEventHandler("KOTH-Gadget:Used", function(id)
    local src = source
    local d = Drops[tonumber(id)]
    if not d or d.owner == src or teamOf(src) ~= d.team or not GetPlayerName(d.owner) then return end
    local key = d.id .. ":" .. src
    if rewarded[key] and os.time() - rewarded[key] < DROP_REWARD_COOLDOWN then return end
    rewarded[key] = os.time()

    local r = DROP_REWARD[d.kind]
    if AddMoneyServer then AddMoneyServer(d.owner, r.money) end
    if AddXpServer then AddXpServer(d.owner, r.xp) end
    TriggerClientEvent("KOTH:RightNotification", d.owner, r.money, r.xp, r.label)
end)

-- players joining late get the drops already on the ground
RegisterNetEvent("KOTH-Gadget:Sync")
AddEventHandler("KOTH-Gadget:Sync", function()
    local src = source
    for _, d in pairs(Drops) do TriggerClientEvent("KOTH-Gadget:Add", src, d) end
end)

AddEventHandler("playerDropped", function()
    local src = source
    for id, d in pairs(Drops) do
        if d.owner == src then removeDrop(id) end
    end
end)

DetectionCache = {}
