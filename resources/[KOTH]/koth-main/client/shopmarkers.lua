-- Floating, spinning 3D icons above your team's shops:
--   weapon shop  -> $  (marker 29)
--   vehicle shop -> car (marker 36)
-- Shown in the team colour, only for your own base.

local TEAM_COLOR = {
    [1] = { 239, 68, 68 },    -- red / OPFOR
    [2] = { 59, 130, 246 },   -- blue / BLUFOR
    [3] = { 34, 197, 94 },    -- green / INDFOR
}
local SHOPS = {
    [1] = { weapon = "posweaponshopR", vehicle = "posvoitureshopR" },
    [2] = { weapon = "posweaponshopB", vehicle = "posvoitureshopB" },
    [3] = { weapon = "posweaponshopG", vehicle = "posvoitureshopG" },
}
local DRAW_DISTANCE = 120.0

local function icon(markerType, pos, c, scale)
    -- big spinning icon
    DrawMarker(markerType, pos.x, pos.y, pos.z + 1.9, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        scale, scale, scale, c[1], c[2], c[3], 220, true, true, 2, true, nil, nil, false)
    -- ring on the ground
    DrawMarker(27, pos.x, pos.y, pos.z - 0.95, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        2.4, 2.4, 1.0, c[1], c[2], c[3], 140, false, false, 2, true, nil, nil, false)
end

Citizen.CreateThread(function()
    while true do
        local team = KOTH and KOTH.TeamID
        local shops = team and SHOPS[team]
        if shops and Possss then
            local me = GetEntityCoords(PlayerPedId())
            local c = TEAM_COLOR[team]
            local w, v = Possss[shops.weapon], Possss[shops.vehicle]
            local near = false
            if w and #(me - w) < DRAW_DISTANCE then icon(29, w, c, 1.3); near = true end
            if v and #(me - v) < DRAW_DISTANCE then icon(36, v, c, 1.3); near = true end
            Wait(near and 0 or 500)
        else
            Wait(1000)
        end
    end
end)
