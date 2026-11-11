-- Death screen (NUI in ui/menu.html). Called from client/death.lua.

DEATH_BLEEDOUT = 90      -- seconds before automatic respawn at base
DEATH_HOLD_MS  = 2500    -- hold E this long to respawn

local WEAPONS = {
    {"WEAPON_ASSAULTRIFLE", "Assault Rifle"}, {"WEAPON_ASSAULTRIFLE_MK2", "Assault Rifle Mk II"},
    {"WEAPON_CARBINERIFLE", "Carbine Rifle"}, {"WEAPON_CARBINERIFLE_MK2", "Carbine Rifle Mk II"},
    {"WEAPON_ADVANCEDRIFLE", "Advanced Rifle"}, {"WEAPON_SPECIALCARBINE", "Special Carbine"},
    {"WEAPON_SPECIALCARBINE_MK2", "Special Carbine Mk II"}, {"WEAPON_BULLPUPRIFLE", "Bullpup Rifle"},
    {"WEAPON_BULLPUPRIFLE_MK2", "Bullpup Rifle Mk II"}, {"WEAPON_COMPACTRIFLE", "Compact Rifle"},
    {"WEAPON_MICROSMG", "Micro SMG"}, {"WEAPON_MACHINEPISTOL", "Machine Pistol"},
    {"WEAPON_SMG", "SMG"}, {"WEAPON_SMG_MK2", "SMG Mk II"}, {"WEAPON_ASSAULTSMG", "Assault SMG"},
    {"WEAPON_COMBATPDW", "Combat PDW"}, {"WEAPON_MINISMG", "Mini SMG"}, {"WEAPON_GUSENBERG", "Gusenberg"},
    {"WEAPON_MG", "MG"}, {"WEAPON_COMBATMG", "Combat MG"}, {"WEAPON_COMBATMG_MK2", "Combat MG Mk II"},
    {"WEAPON_PISTOL", "Pistol"}, {"WEAPON_PISTOL_MK2", "Pistol Mk II"}, {"WEAPON_COMBATPISTOL", "Combat Pistol"},
    {"WEAPON_PISTOL50", "Pistol .50"}, {"WEAPON_SNSPISTOL", "SNS Pistol"}, {"WEAPON_SNSPISTOL_MK2", "SNS Pistol Mk II"},
    {"WEAPON_HEAVYPISTOL", "Heavy Pistol"}, {"WEAPON_VINTAGEPISTOL", "Vintage Pistol"},
    {"WEAPON_MARKSMANPISTOL", "Marksman Pistol"}, {"WEAPON_REVOLVER", "Heavy Revolver"},
    {"WEAPON_REVOLVER_MK2", "Heavy Revolver Mk II"}, {"WEAPON_APPISTOL", "AP Pistol"},
    {"WEAPON_FLAREGUN", "Flare Gun"}, {"WEAPON_PUMPSHOTGUN", "Pump Shotgun"},
    {"WEAPON_PUMPSHOTGUN_MK2", "Pump Shotgun Mk II"}, {"WEAPON_SAWNOFFSHOTGUN", "Sawed-Off Shotgun"},
    {"WEAPON_BULLPUPSHOTGUN", "Bullpup Shotgun"}, {"WEAPON_ASSAULTSHOTGUN", "Assault Shotgun"},
    {"WEAPON_HEAVYSHOTGUN", "Heavy Shotgun"}, {"WEAPON_DBSHOTGUN", "Double Barrel Shotgun"},
    {"WEAPON_AUTOSHOTGUN", "Sweeper Shotgun"}, {"WEAPON_SNIPERRIFLE", "Sniper Rifle"},
    {"WEAPON_HEAVYSNIPER", "Heavy Sniper"}, {"WEAPON_HEAVYSNIPER_MK2", "Heavy Sniper Mk II"},
    {"WEAPON_MARKSMANRIFLE", "Marksman Rifle"}, {"WEAPON_MARKSMANRIFLE_MK2", "Marksman Rifle Mk II"},
    {"WEAPON_GRENADELAUNCHER", "Grenade Launcher"}, {"WEAPON_RPG", "RPG"},
    {"WEAPON_HOMINGLAUNCHER", "Homing Launcher"}, {"WEAPON_MINIGUN", "Minigun"},
    {"WEAPON_RAILGUN", "Railgun"}, {"WEAPON_GRENADE", "Grenade"}, {"WEAPON_PROXMINE", "Proximity Mine"},
    {"WEAPON_MOLOTOV", "Molotov"}, {"WEAPON_UNARMED", "Fists"},
}

local byHash = nil
local function u32(h) return (h or 0) % 4294967296 end

function GetDeathWeaponInfo(hash)
    if not byHash then
        byHash = {}
        for _, w in ipairs(WEAPONS) do byHash[u32(GetHashKey(w[1]))] = w end
    end
    local w = byHash[u32(hash)]
    if w then return w[1], w[2] end
    return nil, nil
end

local shown = false

-- killerPlayer: client player index of the killer (or nil)
function ShowDeathScreen(killerPlayer, killerServerId, weaponHash, inVehicle, vehicleName, distance, headshot)
    if shown then return end
    shown = true

    local weaponId, weaponName = GetDeathWeaponInfo(weaponHash)
    if inVehicle and (not weaponId or weaponId == "WEAPON_UNARMED") then
        weaponId, weaponName = "VEHICLE", vehicleName ~= "" and GetLabelText(vehicleName) or "Vehicle"
    end

    local killer = nil
    if killerPlayer and killerPlayer ~= PlayerId() then
        killer = {
            id = killerServerId,
            name = GetPlayerName(killerPlayer),
        }
    end

    SendNUIMessage({
        type = "death",
        show = true,
        killer = killer,
        weapon = weaponId,
        weaponName = weaponName,
        distance = distance and math.floor(distance) or nil,
        headshot = headshot,
        bleedout = DEATH_BLEEDOUT,
    })
end

function HideDeathScreen()
    if not shown then return end
    shown = false
    SendNUIMessage({ type = "death", show = false })
end

function SetDeathHoldProgress(p)
    SendNUIMessage({ type = "deathHold", progress = p })
end
