-- =======================================================================
--  Client: Karte (Gebiete, Lobby, FFA), Gangwar-Anzeige, Teamkameraden
-- =======================================================================

Map = {
    hoods = {},          -- vom Server: Hoods aller Gangs
    zones = {},          -- vom Server: Besitzer je Gebiet
    zoneBlips = {},
    modeBlips = {},
    mateBlips = {},      -- [serverId] = blip
}

local function nui(data) SendNUIMessage(data) end

local function removeBlips(list)
    for _, b in pairs(list) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
end

local function setName(blip, text)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandSetBlipName(blip)
end

-- Gebiete auf der Karte, eingefärbt nach Besitzer
function Map.drawZones()
    removeBlips(Map.zoneBlips)
    Map.zoneBlips = {}
    if not PvP.loggedIn then return end
    local owners = {}
    for _, z in ipairs(Map.zones) do owners[z.key] = z end
    for _, z in ipairs(Config.Zones) do
        local info = owners[z.key]
        local owner = info and info.owner
        local color = owner and owner.blip or 4
        local radius = AddBlipForRadius(z.center.x, z.center.y, z.center.z, z.radius)
        SetBlipColour(radius, color)
        SetBlipAlpha(radius, 80)
        local blip = AddBlipForCoord(z.center.x, z.center.y, z.center.z)
        SetBlipSprite(blip, 1)
        SetBlipColour(blip, color)
        SetBlipScale(blip, 0.7)
        SetBlipAsShortRange(blip, true)
        if info and info.war then
            SetBlipFlashes(radius, true)
            SetBlipFlashes(blip, true)
        end
        setName(blip, ('Gebiet: %s (%s)'):format(z.name, owner and owner.tag or 'frei'))
        Map.zoneBlips[#Map.zoneBlips + 1] = radius
        Map.zoneBlips[#Map.zoneBlips + 1] = blip
    end
end

-- Hoods aller Gangs, deine eigene Hood + Garage, aktuelle FFA-Arena
function Map.refresh()
    removeBlips(Map.modeBlips)
    Map.modeBlips = {}
    if not PvP.loggedIn then return end
    local add = function(b) Map.modeBlips[#Map.modeBlips + 1] = b end
    local myKey = PvP.team and PvP.team.key

    local ownDrawn = false
    for _, h in ipairs(Map.hoods or {}) do
        local mine = h.key == myKey
        local b = AddBlipForCoord(h.x, h.y, h.z)
        SetBlipSprite(b, 40)
        SetBlipColour(b, tonumber(h.blip) or 0)
        SetBlipScale(b, mine and 1.0 or 0.7)
        SetBlipAsShortRange(b, not mine)
        setName(b, mine and ('Deine Hood: %s'):format(h.name) or ('Hood %s: %s'):format(h.tag or h.team, h.name))
        add(b)
        if mine then ownDrawn = true end
    end
    local hood = PvP.hood
    if hood and hood.spawn and not ownDrawn then                    -- privates Team
        local b = AddBlipForCoord(hood.spawn.x, hood.spawn.y, hood.spawn.z)
        SetBlipSprite(b, 40)
        SetBlipColour(b, 0)
        SetBlipScale(b, 1.0)
        setName(b, ('Deine Hood: %s'):format(hood.name or 'Hood'))
        add(b)
    end
    if hood and hood.garage and Config.Garage.enabled then
        local g = AddBlipForCoord(hood.garage.x, hood.garage.y, hood.garage.z)
        SetBlipSprite(g, 357)
        SetBlipColour(g, 3)
        SetBlipScale(g, 0.7)
        SetBlipAsShortRange(g, true)
        setName(g, 'Garage')
        add(g)
    end

    if PvP.mode == 'ffa' then
        local a = Config.Arenas[PvP.arenaIndex]
        if a then
            local r = AddBlipForRadius(a.center.x, a.center.y, a.center.z, a.radius)
            SetBlipColour(r, 1)
            SetBlipAlpha(r, 100)
            local b = AddBlipForCoord(a.center.x, a.center.y, a.center.z)
            SetBlipSprite(b, 110)
            SetBlipColour(b, 1)
            setName(b, 'FFA: ' .. a.name)
            add(r)
            add(b)
        end
    end
    Map.drawZones()
end

RegisterNetEvent('bspvp:hoods', function(list)
    Map.hoods = type(list) == 'table' and list or {}
    Map.refresh()
end)

RegisterNetEvent('bspvp:zones', function(view)
    Map.zones = type(view) == 'table' and view or {}
    Map.drawZones()
end)

-- -----------------------------------------------------------------------
--  Gangwar-Anzeige
-- -----------------------------------------------------------------------
RegisterNetEvent('bspvp:war', function(state)
    PvP.war = state or nil
    nui({ type = 'war', war = state or false })
end)

RegisterNetEvent('bspvp:warEnd', function(result)
    nui({ type = 'warEnd', result = result })
end)

-- -----------------------------------------------------------------------
--  Teamkameraden: Name über dem Kopf + Blip auf der Karte
-- -----------------------------------------------------------------------
local function drawText3D(x, y, z, text, rgb)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(rgb[1], rgb[2], rgb[3], 235)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
end

local function isMate(sid)
    -- im FFA kämpft jeder für sich: dort keine Team-Markierung (kein Teaming)
    if not PvP.team or PvP.mode == 'login' or PvP.mode == 'select' or PvP.mode == 'ffa' then return false end
    local st = Player(sid).state
    if st.gwTeam ~= PvP.team.key or st.gwMode ~= PvP.mode then return false end
    if PvP.mode == 'gangwar' and st.gwWar ~= (PvP.war and PvP.war.id) then return false end
    return true
end

CreateThread(function()
    local mates = {}
    local lastScan = 0
    while true do
        local now = GetGameTimer()
        if now - lastScan > 500 then
            lastScan = now
            local seen = {}
            mates = {}
            if PvP.loggedIn then
                local me = PlayerId()
                for _, pid in ipairs(GetActivePlayers()) do
                    if pid ~= me then
                        local sid = GetPlayerServerId(pid)
                        if isMate(sid) then
                            local st = Player(sid).state
                            mates[#mates + 1] = {
                                pid = pid,
                                label = ('[%s] %s #%s'):format(st.gwTag or '?', st.gwName or GetPlayerName(pid), tostring(st.gwUid)),
                                rgb = Util.hexToRgb(st.gwColor),
                            }
                            seen[sid] = true
                            local ped = GetPlayerPed(pid)
                            local blip = Map.mateBlips[sid]
                            if not blip or not DoesBlipExist(blip) or GetBlipInfoIdEntityIndex(blip) ~= ped then
                                if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
                                blip = AddBlipForEntity(ped)
                                SetBlipColour(blip, tonumber(st.gwBlip) or 0)
                                SetBlipScale(blip, 0.75)
                                ShowHeadingIndicatorOnBlip(blip, true)
                                setName(blip, st.gwName or 'Team')
                                Map.mateBlips[sid] = blip
                            end
                        end
                    end
                end
            end
            for sid, blip in pairs(Map.mateBlips) do
                if not seen[sid] then
                    if DoesBlipExist(blip) then RemoveBlip(blip) end
                    Map.mateBlips[sid] = nil
                end
            end
        end

        if #mates > 0 then
            local myPos = GetEntityCoords(PlayerPedId())
            for _, m in ipairs(mates) do
                local ped = GetPlayerPed(m.pid)
                if ped ~= 0 and not IsEntityDead(ped) then
                    local p = GetEntityCoords(ped)
                    local dx, dy, dz = p.x - myPos.x, p.y - myPos.y, p.z - myPos.z
                    if dx * dx + dy * dy + dz * dz < 60.0 * 60.0 then
                        drawText3D(p.x, p.y, p.z + 1.1, m.label, m.rgb)
                    end
                end
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

-- -----------------------------------------------------------------------
--  Alle 30 s: Spieler an den Hoods als Punkt in ihrer Gangfarbe + Gang-Name
--  (Teamkameraden in der Nähe haben schon einen Live-Blip)
-- -----------------------------------------------------------------------
Map.playerBlips = {}
RegisterNetEvent('bspvp:playerBlips', function(list)
    removeBlips(Map.playerBlips)
    Map.playerBlips = {}
    if type(list) ~= 'table' or PvP.mode ~= 'lobby' then return end
    for _, e in ipairs(list) do
        if not Map.mateBlips[e.sid] then
            local blip = AddBlipForCoord(e.x + 0.0, e.y + 0.0, e.z + 0.0)
            SetBlipSprite(blip, 1)
            SetBlipColour(blip, tonumber(e.blip) or 0)
            SetBlipScale(blip, 0.7)
            SetBlipAsShortRange(blip, false)
            SetBlipCategory(blip, 7)
            setName(blip, tostring(e.team or 'Gang'))
            Map.playerBlips[#Map.playerBlips + 1] = blip
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    removeBlips(Map.zoneBlips)
    removeBlips(Map.modeBlips)
    removeBlips(Map.mateBlips)
    removeBlips(Map.playerBlips)
end)
