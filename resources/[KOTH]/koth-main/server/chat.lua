-- ============================================================
--  KOTH chat: "[ID] [RANK] Name: message" with team colour bar.
--  Templates / styling: [Fivem]/[gameplay]/chat/html/config.js + index.css
-- ============================================================

local function teamOf(src)
    for _, t in pairs(TeamIDPlayer or {}) do if t.id == src then return t.team end end
    return 0
end

local function rankOf(src)
    if GetStaffRank and GetStaffRank(src) > 0 then return "Staff" end
    if IsVip and IsVip(src) then return "VIP" end
    return "User"
end

AddEventHandler("chatMessage", function(src, name, message)
    CancelEvent() -- we send our own formatted message below
    src = tonumber(src)
    if not src or not message or message == "" or message:sub(1, 1) == "/" then return end
    message = message:sub(1, 256)

    local p = StatsGetPlayer and StatsGetPlayer(src)
    local id = (p and p.dbId) or src
    local prestige = GetPrestige and GetPrestige(src) or 0

    TriggerClientEvent("chat:addMessage", -1, {
        templateId = "koth",
        args = { tostring(id), rankOf(src), GetPlayerName(src) or name, message, tostring(teamOf(src)), tostring(prestige), GetChatTag and GetChatTag(src) or "" },
    })
end)
