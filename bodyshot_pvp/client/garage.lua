-- =======================================================================
--  Client: Garage an der Hood und am Gangwar-Spawn (E) + reparieren (F3)
--  Autos kommen in der Teamfarbe mit Neon. Der Server löscht sie wieder,
--  sobald man den Modus wechselt oder den Server verlässt.
-- =======================================================================

Garage = { vehicle = nil, near = false, lastRepair = -100000 }

local function nui(data) SendNUIMessage(data) end

-- Moduswechsel: das Auto löscht der Server, hier nur die Referenz vergessen
function Garage.forget()
    Garage.vehicle = nil
    if Garage.near then
        Garage.near = false
        HUD.prompt('garage', false)
    end
end

local function deleteOwn()
    local v = Garage.vehicle
    if v and DoesEntityExist(v) and NetworkHasControlOfEntity(v) then
        SetEntityAsMissionEntity(v, true, true)
        DeleteVehicle(v)
    end
    Garage.vehicle = nil
end

-- -----------------------------------------------------------------------
--  Marker + Hinweis "E  Garage"
-- -----------------------------------------------------------------------
-- Wo steht gerade die Garage? Hood: fester Punkt. Gangwar: Straße am eigenen Team-Spawn.
local function garagePoint()
    if PvP.mode == 'lobby' then return PvP.hood and PvP.hood.garage end
    if PvP.mode == 'gangwar' and PvP.gwBase then return PvP.gwBase.garage end
    return nil
end
Garage.point = garagePoint

CreateThread(function()
    while true do
        local sleep = 500
        local near = false
        local g = Config.Garage.enabled and PvP.loggedIn and not PvP.dead and garagePoint()
        if g then
            local ped = PlayerPedId()
            local p = GetEntityCoords(ped)
            local dx, dy, dz = p.x - g.x, p.y - g.y, p.z - g.z
            local d2 = dx * dx + dy * dy
            if d2 < 45.0 * 45.0 then
                sleep = 0
                DrawMarker(36, g.x, g.y, g.z + 1.15, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.9, 0.9, 0.9,
                    14, 165, 255, 210, true, true, 2, false, nil, nil, false)
                DrawMarker(25, g.x, g.y, g.z + 0.03, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.4, 2.4, 1.0,
                    14, 165, 255, 150, false, false, 2, false, nil, nil, false)
                near = d2 < 2.6 * 2.6 and math.abs(dz) < 3.0 and not IsPedInAnyVehicle(ped, false) and UI.screen == nil
            end
        end
        if near ~= Garage.near then
            Garage.near = near
            HUD.prompt('garage', near, Config.Keys.interact or 'E', PvP.mode == 'gangwar' and 'Gangwar-Garage' or 'Garage')
        end
        Wait(sleep)
    end
end)

RegisterCommand('gwinteract', function()
    if Garage.near and UI.screen == nil then
        TriggerServerEvent('bspvp:garage:open')
    end
end, false)
RegisterKeyMapping('gwinteract', 'Garage öffnen (Hood und Gangwar-Spawn)', 'keyboard', Config.Keys.interact or 'E')

RegisterNetEvent('bspvp:garage', function(data)
    if type(data) ~= 'table' or not garagePoint() then return end
    UI.openScreen('garage', { type = 'garage', data = data })
end)

RegisterNUICallback('garageSpawn', function(data, cb)
    if data and data.model then
        TriggerServerEvent('bspvp:garage:spawn', tostring(data.model))
    end
    UI.close('garage')
    cb({})
end)

-- -----------------------------------------------------------------------
--  Auto ausparken (der Server hat Level, Abstand und Wartezeit geprüft)
-- -----------------------------------------------------------------------
local function freeSpot(c)
    local x, y, z, hdg = c.x, c.y, c.z, (c.w or 0.0) + 0.0
    local r = math.rad(hdg)
    for _ = 0, 3 do
        if not IsAnyVehicleNearPoint(x, y, z, 2.5) then break end
        x, y = x + math.sin(r) * 6.0, y - math.cos(r) * 6.0       -- ein Stück nach hinten
    end
    return x, y, z, hdg
end

-- Gangwar: Auto auf die Straße direkt neben dem Spieler, Fahrtrichtung zur Bubble
local function gangwarCarSpot()
    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)
    local ok, node, heading = GetClosestVehicleNodeWithHeading(p.x, p.y, p.z, 0, 3.0, 0)
    if not ok or not node then
        local f = GetEntityForwardVector(ped)
        return { x = p.x + f.x * 4.0, y = p.y + f.y * 4.0, z = p.z, w = GetEntityHeading(ped) }
    end
    local area = PvP.area()
    if area then
        -- Straßenrichtung so drehen, dass die Schnauze zur Bubble zeigt
        local toZone = GetHeadingFromVector_2d(area.center.x - node.x, area.center.y - node.y)
        local diff = math.abs(((heading - toZone) + 180.0) % 360.0 - 180.0)
        if diff > 90.0 then heading = (heading + 180.0) % 360.0 end
    end
    return { x = node.x, y = node.y, z = node.z + 0.5, w = heading }
end

RegisterNetEvent('bspvp:garage:spawn', function(d)
    if type(d) ~= 'table' or PvP.dead or not garagePoint() then return end
    if d.gangwar then
        if PvP.mode ~= 'gangwar' then return end
        d.car = gangwarCarSpot()
    elseif PvP.mode ~= 'lobby' or type(d.car) ~= 'table' then
        return
    end
    local hash = GetHashKey(d.model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        return HUD.notify('error', ('%s gibt es in deiner Spielversion nicht.'):format(d.label or d.model))
    end
    RequestModel(hash)
    local timeout = GetGameTimer() + 8000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(0) end
    if not HasModelLoaded(hash) then
        return HUD.notify('error', 'Das Auto konnte nicht geladen werden. Versuch es gleich nochmal.')
    end
    deleteOwn()

    local x, y, z, hdg = freeSpot(d.car)
    local veh = CreateVehicle(hash, x, y, z, hdg, true, false)
    SetModelAsNoLongerNeeded(hash)
    if not veh or veh == 0 then return end

    SetVehicleOnGroundProperly(veh)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetVehicleNeedsToBeHotwired(veh, false)
    SetVehRadioStation(veh, 'OFF')
    SetVehicleNumberPlateText(veh, d.plate or 'GANG')
    SetVehicleModKit(veh, 0)
    local col = type(d.color) == 'table' and d.color or { 255, 255, 255 }
    SetVehicleCustomPrimaryColour(veh, col[1], col[2], col[3])
    SetVehicleCustomSecondaryColour(veh, 16, 16, 18)
    SetVehicleWindowTint(veh, 1)
    ToggleVehicleMod(veh, 20, true)                                 -- Reifenrauch in Teamfarbe
    SetVehicleTyreSmokeColor(veh, col[1], col[2], col[3])
    for i = 0, 3 do SetVehicleNeonLightEnabled(veh, i, true) end
    SetVehicleNeonLightsColour(veh, col[1], col[2], col[3])
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleEngineOn(veh, true, true, false)
    TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
    Garage.vehicle = veh

    local netId = NetworkGetNetworkIdFromEntity(veh)
    SetNetworkIdCanMigrate(netId, true)
    TriggerServerEvent('bspvp:garage:spawned', netId)
    HUD.notify('success', ('%s ausgeparkt.'):format(d.label or d.model))
end)

-- -----------------------------------------------------------------------
--  F3: Fahrzeug reparieren
-- -----------------------------------------------------------------------
RegisterCommand('gwrepair', function()
    if not PvP.loggedIn or PvP.dead then return end
    if PvP.mode ~= 'lobby' then
        return HUD.notify('error', 'Reparieren geht nicht im FFA oder Gangwar.')
    end
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        return HUD.notify('error', 'Setz dich zuerst in ein Fahrzeug.')
    end
    local wait = Garage.lastRepair + (Config.Garage.repairCooldown or 30) * 1000 - GetGameTimer()
    if wait > 0 then
        return HUD.notify('error', ('Reparieren geht wieder in %d Sekunden.'):format(math.ceil(wait / 1000)))
    end
    SetVehicleFixed(veh)
    SetVehicleDeformationFixed(veh)
    SetVehicleUndriveable(veh, false)
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleBodyHealth(veh, 1000.0)
    SetVehiclePetrolTankHealth(veh, 1000.0)
    SetVehicleDirtLevel(veh, 0.0)
    WashDecalsFromVehicle(veh, 1.0)
    SetVehicleEngineOn(veh, true, true, false)
    Garage.lastRepair = GetGameTimer()
    HUD.notify('success', 'Fahrzeug repariert.')
end, false)
RegisterKeyMapping('gwrepair', 'Fahrzeug reparieren', 'keyboard', Config.Keys.repair or 'F3')

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    deleteOwn()
end)
