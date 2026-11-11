-- /stats (F7) and /prestige: all-time career stats, top players, prestige

local openTab = "stats"

local function open(tab)
    openTab = tab
    TriggerServerEvent("KOTH-Plus:GetCareer")
end

RegisterCommand("stats", function() open("stats") end, false)
RegisterCommand("prestige", function() open("prestige") end, false)
RegisterKeyMapping("stats", "Open career stats", "keyboard", "F7")

RegisterNetEvent("KOTH-Plus:Career")
AddEventHandler("KOTH-Plus:Career", function(data)
    data.tab = openTab
    data.name = GetPlayerName(PlayerId())
    Plus.Open("career", data)
end)

RegisterNUICallback("prestige", function(_, cb)
    TriggerServerEvent("KOTH-Plus:Prestige")
    cb("ok")
end)

RegisterNetEvent("KOTH-Plus:PrestigeDone")
AddEventHandler("KOTH-Plus:PrestigeDone", function(p)
    Plus.Close()
    Plus.Send("career", "close")
    Plus.Send("bigmsg", "show", { title = "PRESTIGE " .. p, sub = "Level reset to 1 · +$25,000 · +" .. (p * 5) .. "% XP", color = "purple" })
    PlaySoundFrontend(-1, "RANK_UP", "HUD_AWARDS", true)
end)
