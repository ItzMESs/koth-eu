-- KOTH scoreboard: hold TAB to show.
-- The server sends the sorted PlayerDataInfo table every second
-- ({id, name, kill, death, assist, score, money, xp, color}).

local scoreboardOn = false

Citizen.CreateThread(function()
    Wait(250)
    while true do
        TriggerServerEvent("KOTH-HUD:Update")
        Wait(1000)
    end
end)

RegisterNetEvent("KOTH-HUD:OPEN")
AddEventHandler("KOTH-HUD:OPEN", function(players)
    SendNUIMessage({
        action = "update",
        players = players,
        selfId = GetPlayerServerId(PlayerId())
    })
end)

Citizen.CreateThread(function()
    Wait(1000)
    while true do
        Citizen.Wait(0)
        if IsControlPressed(0, 211) and GetLastInputMethod(0) then -- TAB
            if not scoreboardOn then
                scoreboardOn = true
                SendNUIMessage({action = "show"})
            end
        elseif scoreboardOn then
            scoreboardOn = false
            SendNUIMessage({action = "hide"})
        end
    end
end)
