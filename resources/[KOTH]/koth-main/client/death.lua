local timer = 0
local pressTimer = 0
isDead = false


AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkEntityDamage' then
        local victim = args[1]
        local attacker = args[2]
        if GetEntityType(attacker) == 1 and GetEntityType(victim) == 1 then
            if GetPlayerServerId(PlayerId()) == GetPlayerServerId(GetPlayerByEntityID(attacker)) then
                if GetPlayerServerId(PlayerId()) ~= GetPlayerServerId(GetPlayerByEntityID(victim)) then
                    TriggerEvent('kInteractSound_CL:PlayOnOne', 'hit', 0.35)
                    if GetEntityHealth(victim) <= 0 then
                        KillByPed = KillByPed + 1
                    end
                    if GetEntityHealth(victim) <= 175 then
                        TriggerServerEvent('koth:addPendingAssist', GetPlayerServerId(GetPlayerByEntityID(victim)))
                    end
                end
            end
        end
    end
end)


function GetPedVehicleSeat(ped)
    local vehicle = GetVehiclePedIsIn(ped, false)
    for i=-2,GetVehicleMaxNumberOfPassengers(vehicle) do
        if(GetPedInVehicleSeat(vehicle, i) == ped) then return i end
    end
    return -2
end


function secondsToClock(seconds)
	local mins = tonumber(seconds),0,0,0

	if seconds <= 0 then
		return 0, 0
	else
		local hours = string.format('%02.f', math.floor(seconds / 3600))
		local mins = string.format('%02.f', math.floor(seconds / 60 - (hours * 60)))
		local secs = string.format('%02.f', math.floor(seconds - hours * 3600 - mins * 60))

		return secs
	end
end
local sec = 60000*5

Citizen.CreateThread(function()
    local hasBeenDead = false
    local diedAt
    local interval = 1
    while true do
        Wait(interval)
        local player = PlayerId()
        if NetworkIsPlayerActive(player) then
            local ped = PlayerPedId()
            if IsEntityDead(ped) then
                --interval = 1000
                isDead = true
                if not diedAt then
                	diedAt = GetGameTimer()
                end

                local driverid = -1
                local killer, killerweapon = NetworkGetEntityKillerOfPlayer(player)
				local killerentitytype = GetEntityType(killer)
				local killertype = -1
                local killerinvehicle = false
                local killersharedveh = false
                local destroyedveh = false
				local killervehiclename = ''
                local killervehicleseat = 0
                local killerid = GetPlayerByEntityID(killer)

                -- Death Screen
                local pPed = GetPlayerPed(-1)
                local pCoords = GetEntityCoords(pPed)
                local heading GetEntityHeading(pPed)
                --NetworkResurrectLocalPlayer(pCoords, heading, 0, 0)
                StartAudioScene("SWITCH_TO_MP_SCENE")
                StartScreenEffect("DeathFailOut", -1, true)

                -- (the old native-text timer used to live here; the death
                --  screen is now NUI, see client/deathscreen.lua)
                if isDead then
                    Wait(1000)
                end
                local killerPlayerIdx = killerid

                local attacker_hipfire = not DecorGetBool(killer, '_IS_AIMING')

				if killerentitytype == 1 then
					killertype = GetPedType(killer)
					if IsPedInAnyVehicle(killer, false) == 1 then
						killerinvehicle = true
						killervehiclename = GetDisplayNameFromVehicleModel(GetEntityModel(GetVehiclePedIsUsing(killer)))
                        killervehicleseat = GetPedVehicleSeat(killer)
                        if killervehicleseat ~= -1 then
                            -- Driver Assisted Kill
                            local veh = GetVehiclePedIsIn(killer)
                            local driver = GetPedInVehicleSeat(veh, -1)
                            driverid = GetPlayerServerId(GetPlayerByEntityID(driver))
                        end
					else 
                        killerinvehicle = false
					end
				end
                
                if not killerid then 
                    killerid = -1 
                end
                pDeath = true
                -- Vehicle Destroyed
                if IsPedInAnyVehicle(ped) then
                    local vehicle = GetVehiclePedIsIn(ped, true)
                    if GetEntityHealth(vehicle) <= 100 then
                        destroyedveh = true
                    end
                end

                -- Remove all ped attachment

                -- Check if killer and killed are in same vehicle
                if IsPedInAnyVehicle(killer, false) == 1 then
                    local vehicle = GetVehiclePedIsUsing(killer)
                    for i=0, GetVehicleMaxNumberOfPassengers(vehicle) do
                        local pass = GetPedInVehicleSeat(vehicle, i)
                        if PlayerPedId() == pass then
                            killersharedveh = true
                        end
                    end
                end

				if killer ~= ped and killerid ~= nil and NetworkIsPlayerActive(killerid) then 
                    killerid = GetPlayerServerId(killerid)
				else 
                    killerid = -1
				end

                local killdist = #(GetEntityCoords(killer) - GetEntityCoords(ped))
                if not killdist then 
                    killdist = 0 
                end

                -- Check if headshot
                local headshot = false
                local _, outbone = GetPedLastDamageBone(ped)
                if outbone == 31086 then
                    headshot = true
                end

                ShowDeathScreen(killerPlayerIdx, killerid, killerweapon, killerinvehicle, killervehiclename, killdist, headshot)

                if killer == ped or killer == -1 then
                    TriggerEvent('baseevents:onPlayerDied', killertype, { table.unpack(GetEntityCoords(ped)) })
                    TriggerServerEvent('baseevents:onPlayerDied', killertype, { table.unpack(GetEntityCoords(ped)) })
                    hasBeenDead = true
                else

                    TriggerServerEvent('baseevents:onPlayerKilled', killerid, {
                        hipfire = attacker_hipfire, 
                        killersharedveh = killersharedveh, 
                        headshot = headshot, 
                        killdistance=killdist, 
                        killertype=killertype, 
                        weaponhash = killerweapon,
                        zoned = zoneKill, 
                        killerinveh=killerinvehicle, 
                        driverid=driverid, 
                        destroyveh=destroyedveh, 
                        killervehseat=killervehicleseat, 
                        killervehname=killervehiclename, 
                        killerpos={table.unpack(GetEntityCoords(ped))}
                    }, KOTH.TeamID)
                    Wait(1500)
                    hasBeenDead = true
                end
                TriggerEvent('koth-core:PlayerDied')
            elseif not IsPedFatallyInjured(ped) then
                --isDead = false
                diedAt = nil
            end
            -- check if the player has to respawn in order to trigger an event
            if not hasBeenDead and diedAt ~= nil and diedAt > 0 then
                TriggerEvent('baseevents:onPlayerWasted', { table.unpack(GetEntityCoords(ped)) })
                TriggerServerEvent('baseevents:onPlayerWasted', { table.unpack(GetEntityCoords(ped)) })
                hasBeenDead = true
            elseif hasBeenDead and diedAt ~= nil and diedAt <= 0 then
                hasBeenDead = false
            end
        end
    end
end)


function Round(value, numDecimalPlaces)
    return tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", value))
end

RegisterNetEvent('koth-death:Distress')
AddEventHandler('koth-death:Distress', function()
    distressSent = false
end)

-- Respawn: hold E (DEATH_HOLD_MS) or bleed out after DEATH_BLEEDOUT seconds
Citizen.CreateThread(function()
    local deadSince = nil
    local holdStart = nil
    local lastSent = -1
    while true do
        Citizen.Wait(0)
        if isDead then
            local now = GetGameTimer()
            deadSince = deadSince or now

            local respawn = false
            if IsControlPressed(0, 38) then
                holdStart = holdStart or now
                local p = math.min(1.0, (now - holdStart) / DEATH_HOLD_MS)
                local step = math.floor(p * 50)
                if step ~= lastSent then
                    lastSent = step
                    SetDeathHoldProgress(p)
                end
                if p >= 1.0 then respawn = true end
            elseif holdStart then
                holdStart = nil
                lastSent = -1
                SetDeathHoldProgress(0)
            end

            if (now - deadSince) >= DEATH_BLEEDOUT * 1000 then
                respawn = true
            end

            if respawn then
                holdStart, deadSince, lastSent = nil, nil, -1
                TriggerEvent('core:ResetDeathStatus', false)
                TriggerEvent("KOTH:ReturnBase")
                isDead = false
            end
        else
            deadSince, holdStart = nil, nil
            Citizen.Wait(250)
        end
    end
end)

-- Scale form functions (ignore for sanity)
function buttonHeld(key, timed)
    while IsControlPressed(0, key) do
        Citizen.Wait(0)
        pressTimer = pressTimer + 1
        if pressTimer > timed then
            pressTimer = 0
            return true
        end
    end
    if IsControlJustReleased(0, key) then
        pressTimer = 0
    end
end


function GetPlayerByEntityID(id)
	for i = 0, 255 do
		if(NetworkIsPlayerActive(i) and GetPlayerPed(i) == id) then 
            return i 
        end
	end
	return nil
end


RegisterNetEvent("core:ResetDeathStatus")
AddEventHandler("core:ResetDeathStatus", function(alors)
    TriggerServerEvent("SendLogs","Player revive "..GetPlayerName(PlayerId()).." !", "revive")
    HideDeathScreen()
    ClearPedBloodDamage(PlayerPedId())
    if alors then
        isDead = false

        NetworkSetVoiceActive(true)
        StopScreenEffect('DeathFailOut')
        StopAudioScenes()
        StopGameplayHint(true)
        local coords = GetEntityCoords(GetPlayerPed(-1))
        SetEntityHealth(GetPlayerPed(-1), 200)
        SetEntityCoordsNoOffset(GetPlayerPed(-1), coords, 0.0, 0.0, 0.0)
        NetworkResurrectLocalPlayer(GetEntityCoords(GetPlayerPed(-1)), 100.0, 0, 0)
        ClearPlayerWantedLevel(GetPlayerIndex())
        SetPedCurrentWeaponVisible(GetPlayerPed(-1), false, true, 1, 1)
        StopScreenEffect('DeathFailOut')
        StopAudioScenes()
        StopGameplayHint(true)
        sec = 60000*5

    else
        isDead = false

        NetworkSetVoiceActive(true)
        StopScreenEffect('DeathFailOut')
        StopAudioScenes()
        StopGameplayHint(true)
        local coords = GetEntityCoords(GetPlayerPed(-1))
        SetEntityHealth(GetPlayerPed(-1), 200)
        SetEntityCoordsNoOffset(GetPlayerPed(-1), coords, 0.0, 0.0, 0.0)
        NetworkResurrectLocalPlayer(GetEntityCoords(GetPlayerPed(-1)), 100.0, 0, 0)
        ClearPlayerWantedLevel(GetPlayerIndex())
        SetPedCurrentWeaponVisible(GetPlayerPed(-1), false, true, 1, 1)
        StopScreenEffect('DeathFailOut')
        StopAudioScenes()
        StopGameplayHint(true)
        KillByPed = 0
        IsPlayerDead1 = false
        IsPlayerDead2 = false
        TriggerEvent("KOTH-MEDIC",3)
        
        sec = 60000*5
    end
end)


function DisplayMessage(msg)
    local scaleform = RequestScaleformMovie("instructional_buttons")
    while not HasScaleformMovieLoaded(scaleform) do
        Citizen.Wait(0)
    end
    PushScaleformMovieFunction(scaleform, "CLEAR_ALL")
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, "SET_CLEAR_SPACE")
    PushScaleformMovieFunctionParameterInt(200)
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, "SET_DATA_SLOT")
    PushScaleformMovieFunctionParameterInt(0)
    N_0xe83a3e3557a56640(GetControlInstructionalButton(2, 38, true))
    AddTextEntry("respawn", msg)
    BeginTextCommandScaleformString("respawn")
    EndTextCommandScaleformString()
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, "DRAW_INSTRUCTIONAL_BUTTONS")
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, "SET_BACKGROUND_COLOUR")
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(80)
    PopScaleformMovieFunctionVoid()
    DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 170, 0)
end

