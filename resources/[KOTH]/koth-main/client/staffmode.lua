-- Staff mode flag used by the anti-cheat, player names and /car.
-- Set by the server when a staff member toggles staff mode in the
-- admin panel (koth-plus / koth-main/server/admin.lua).
staffService = false

RegisterNetEvent("KOTH-Admin:StaffMode")
AddEventHandler("KOTH-Admin:StaffMode", function(on)
    staffService = on and true or false
end)
