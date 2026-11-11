-- /report
RegisterCommand("report", function() TriggerServerEvent("KOTH-Report:Open") end, false)

RegisterNetEvent("KOTH-Report:Data")
AddEventHandler("KOTH-Report:Data", function(data)
    data.me = GetPlayerServerId(PlayerId())
    Plus.Open("report", data)
end)

RegisterNUICallback("report", function(data, cb)
    TriggerServerEvent("KOTH-Report:Submit", tonumber(data.target), data.reason, data.details)
    Plus.Close()
    cb("ok")
end)
