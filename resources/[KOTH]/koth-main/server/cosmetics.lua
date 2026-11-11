-- ============================================================
--  Cosmetics shop: hats and chat tags (flags), paid with coins.
--  UI: koth-plus (F6 or /cosmetics).
--  Coins: earned in game (below) or given by staff:
--     console: addcoins <server id> <amount>
--     admin panel (F11) -> player -> Give coins
-- ============================================================

COINS_PER_KILL = 1
COINS_PER_WIN  = 25
COINS_PER_LOSS = 10

-- Hats = prop 0 of the freemode male model (drawable / texture).
-- If a hat looks wrong in game, change its drawable number here.
COSMETIC_HATS = {
    { id = "beanie",    label = "Beanie",         drawable = 2,  texture = 0, price = 300,  icon = "fa-hat-wizard" },
    { id = "cap",       label = "Baseball cap",   drawable = 4,  texture = 0, price = 400,  icon = "fa-hat-cowboy-side" },
    { id = "capback",   label = "Cap backwards",  drawable = 55, texture = 0, price = 500,  icon = "fa-hat-cowboy-side" },
    { id = "flatcap",   label = "Flat cap",       drawable = 7,  texture = 0, price = 600,  icon = "fa-hat-cowboy-side" },
    { id = "fedora",    label = "Fedora",         drawable = 29, texture = 0, price = 800,  icon = "fa-user-tie" },
    { id = "trilby",    label = "Trilby",         drawable = 21, texture = 0, price = 800,  icon = "fa-user-tie" },
    { id = "cowboy",    label = "Cowboy hat",     drawable = 13, texture = 0, price = 1100, icon = "fa-hat-cowboy" },
    { id = "bandana",   label = "Bandana",        drawable = 14, texture = 0, price = 600,  icon = "fa-mask" },
    { id = "tophat",    label = "Top hat",        drawable = 26, texture = 0, price = 1500, icon = "fa-hat-wizard" },
    { id = "sombrero",  label = "Sombrero",       drawable = 20, texture = 0, price = 1100, icon = "fa-hat-cowboy" },
    { id = "beret",     label = "Military beret", drawable = 106, texture = 0, price = 1500, icon = "fa-star", vip = true },
    { id = "crownhat",  label = "Golden crown",   drawable = 115, texture = 0, price = 3000, icon = "fa-crown", vip = true },
}

-- Chat tags = flag shown before your name in chat (ISO country code)
COSMETIC_TAGS = {
    { id = "mn", label = "Mongolia",      price = 0 },
    { id = "kz", label = "Kazakhstan",    price = 600 },
    { id = "ru", label = "Russia",        price = 600 },
    { id = "cn", label = "China",         price = 600 },
    { id = "kr", label = "South Korea",   price = 600 },
    { id = "jp", label = "Japan",         price = 600 },
    { id = "us", label = "United States", price = 600 },
    { id = "gb", label = "Great Britain", price = 600 },
    { id = "de", label = "Germany",       price = 600 },
    { id = "fr", label = "France",        price = 600 },
    { id = "tr", label = "Turkey",        price = 600 },
    { id = "ua", label = "Ukraine",       price = 600 },
    { id = "lt", label = "Lithuania",     price = 600 },
    { id = "br", label = "Brazil",        price = 600 },
    { id = "un", label = "United Nations", price = 2000, vip = true },
}

local ITEMS = {}
for _, h in ipairs(COSMETIC_HATS) do ITEMS["hat:" .. h.id] = { kind = "hat", def = h } end
for _, t in ipairs(COSMETIC_TAGS) do ITEMS["tag:" .. t.id] = { kind = "tag", def = t } end

local C = {}   -- [src] = { license, coins, hat, tag, owned = { ["hat:x"] = true } }

Citizen.CreateThread(function()
    Wait(1500)
    MySQL.Async.execute([[CREATE TABLE IF NOT EXISTS `player_cosmetics` (
        `license` varchar(64) NOT NULL,
        `coins` int(11) NOT NULL DEFAULT 0,
        `hat` varchar(32) DEFAULT NULL,
        `tag` varchar(32) DEFAULT NULL,
        `owned` text DEFAULT NULL,
        PRIMARY KEY (`license`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]], {})
end)

local function save(src)
    local c = C[src]
    if not c then return end
    local owned = {}
    for k in pairs(c.owned) do owned[#owned + 1] = k end
    MySQL.Async.execute([[INSERT INTO player_cosmetics (license, coins, hat, tag, owned) VALUES (@l, @c, @h, @t, @o)
        ON DUPLICATE KEY UPDATE coins = VALUES(coins), hat = VALUES(hat), tag = VALUES(tag), owned = VALUES(owned)]],
        { ['@l'] = c.license, ['@c'] = c.coins, ['@h'] = c.hat, ['@t'] = c.tag, ['@o'] = table.concat(owned, ",") })
end

local function hatDef(id)
    local it = id and ITEMS["hat:" .. id]
    return it and it.def or nil
end

local function sendState(src)
    local c = C[src]
    if not c then return end
    local h = hatDef(c.hat)
    TriggerClientEvent("KOTH-Cosmetics:State", src, {
        coins = c.coins, hat = c.hat, tag = c.tag, owned = c.owned,
        hatProp = h and { drawable = h.drawable, texture = h.texture } or false,
        vip = IsVip and IsVip(src) or false,
        hats = COSMETIC_HATS, tags = COSMETIC_TAGS,
        coinsPerKill = COINS_PER_KILL, coinsPerWin = COINS_PER_WIN,
    })
end

local function load(src)
    local license = GetIdentifierFromId(src)
    if not license then return end
    MySQL.Async.fetchAll('SELECT * FROM player_cosmetics WHERE license = @l', { ['@l'] = license }, function(r)
        local row = r and r[1] or {}
        local c = { license = license, coins = tonumber(row.coins) or 0, hat = row.hat, tag = row.tag, owned = {} }
        for id in string.gmatch(row.owned or "", "[^,]+") do
            if ITEMS[id] then c.owned[id] = true end
        end
        -- free items are always owned
        for key, it in pairs(ITEMS) do if (it.def.price or 0) == 0 then c.owned[key] = true end end
        C[src] = c
        sendState(src)
    end)
end

RegisterNetEvent("KOTH-Plus:Ready")
AddEventHandler("KOTH-Plus:Ready", function()
    local src = source
    if C[src] then sendState(src) else load(src) end
end)

AddEventHandler("playerDropped", function()
    local src = source
    save(src)
    C[src] = nil
end)

-- ---------- helpers used by other files ----------
function GetChatTag(src)
    local c = C[tonumber(src)]
    return c and c.tag or ""
end

function AddCoins(src, amount)
    src = tonumber(src)
    local c = C[src]
    amount = math.floor(tonumber(amount) or 0)
    if not c or amount == 0 then return end
    c.coins = math.max(0, c.coins + amount)
    save(src)
    sendState(src)
end

-- ---------- shop ----------
RegisterNetEvent("KOTH-Cosmetics:Buy")
AddEventHandler("KOTH-Cosmetics:Buy", function(key)
    local src = source
    local c, it = C[src], ITEMS[key]
    if not c or not it then return end
    local notify = function(msg, kind) TriggerClientEvent("KOTH-Plus:Notify", src, msg, kind) end
    if c.owned[key] then return notify("You already own this.", "info") end
    if it.def.vip and not (IsVip and IsVip(src)) then return notify("This item is VIP only.", "error") end
    local price = tonumber(it.def.price) or 0
    if c.coins < price then return notify("Not enough coins.", "error") end
    c.coins = c.coins - price
    c.owned[key] = true
    if it.kind == "hat" then c.hat = it.def.id else c.tag = it.def.id end
    save(src)
    sendState(src)
    notify(("Bought %s for %d coins."):format(it.def.label, price), "success")
    TriggerEvent("SendLogs", ("%s bought cosmetic %s (%d coins)"):format(GetPlayerName(src), key, price), "owned")
end)

RegisterNetEvent("KOTH-Cosmetics:Equip")
AddEventHandler("KOTH-Cosmetics:Equip", function(key)
    local src = source
    local c = C[src]
    if not c then return end
    if key == "hat:none" then c.hat = nil
    elseif key == "tag:none" then c.tag = nil
    else
        local it = ITEMS[key]
        if not it or not c.owned[key] then return end
        if it.def.vip and not (IsVip and IsVip(src)) then
            return TriggerClientEvent("KOTH-Plus:Notify", src, "This item is VIP only.", "error")
        end
        if it.kind == "hat" then c.hat = it.def.id else c.tag = it.def.id end
    end
    save(src)
    sendState(src)
end)

-- ---------- coins from playing ----------
CosmeticsOnKill = function(killer) AddCoins(killer, COINS_PER_KILL) end
CosmeticsOnMatchEnd = function(src, win) AddCoins(src, win and COINS_PER_WIN or COINS_PER_LOSS) end

RegisterCommand("addcoins", function(source, args)
    local target, amount = tonumber(args[1]), tonumber(args[2])
    if source ~= 0 and not (GetStaffRank and GetStaffRank(source) >= 3) then return end
    if not target or not amount or not C[target] then
        return print("Usage: addcoins <server id> <amount>  (player must be online)")
    end
    AddCoins(target, amount)
    print(("[Cosmetics] %s now has %d coins"):format(GetPlayerName(target), C[target].coins))
    TriggerClientEvent("KOTH-Plus:Notify", target, ("You received %d coins!"):format(amount), "success")
end, false)
