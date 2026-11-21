-- =======================================================================
--  Hoods (Spawn jedes Teams) + Garage
--  Positionen kommen aus der Config und können im Spiel mit /sethood
--  überschrieben werden (gespeichert in der KVP unter "hoods").
-- =======================================================================

Hoods = { overrides = {} }   -- [teamKey] = { spawn = {...}, garage = {...}, car = {...} }

local int = Util.int

function Hoods.load()
    local saved = DB.get('hoods')
    Hoods.overrides = type(saved) == 'table' and saved or {}
end

-- Hood aus der Config für ein Team
local function baseHood(ref)
    if not ref then return nil end
    if ref.kind == 'gang' then
        local g = Util.gang(ref.id)
        return g and g.hood
    elseif ref.kind == 'private' then
        local list = Config.PrivateTeams.hoods or {}
        if #list == 0 then return nil end
        return list[((int(ref.id) - 1) % #list) + 1]
    end
    return nil
end

local function fallback()
    local c = Config.Lobby.center
    return {
        name = 'Lobby',
        spawn = vector4(c.x, c.y, c.z, 0.0),
        garage = vector3(c.x + 6.0, c.y, c.z - 1.0),
        car = vector4(c.x + 10.0, c.y, c.z - 0.5, 0.0),
    }
end

-- Fertige Hood als einfache Tabellen (für Client und Menü)
function Hoods.get(ref)
    local base = baseHood(ref) or fallback()
    local key = Teams.key(ref)
    local o = key and Hoods.overrides[key] or {}
    return {
        name = base.name or 'Hood',
        spawn = o.spawn or Util.vec(base.spawn),
        garage = o.garage or Util.vec(base.garage),
        car = o.car or Util.vec(base.car),
        radius = Config.HoodRadius or 60.0,
    }
end

-- Admin: aktuelle Position als Spawn/Garage/Auto speichern
-- Spieler dieses Teams bekommen die geänderte Hood, alle die neuen Karten-Blips
local function pushHood(key)
    for _, p in pairs(Players) do
        if p.loggedIn and Teams.key(p.team) == key then
            TriggerClientEvent('bspvp:hood', p.src, Hoods.get(p.team))
        end
    end
    TriggerClientEvent('bspvp:hoods', -1, Hoods.mapView())
end

function Hoods.set(ref, what, coords, heading)
    local key = Teams.key(ref)
    if not key or (what ~= 'spawn' and what ~= 'garage' and what ~= 'car') then return false end
    Hoods.overrides[key] = Hoods.overrides[key] or {}
    Hoods.overrides[key][what] = { x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0, w = (heading or 0.0) + 0.0 }
    DB.set('hoods', Hoods.overrides)
    pushHood(key)
    return true
end

function Hoods.reset(ref)
    local key = Teams.key(ref)
    if not key then return false end
    Hoods.overrides[key] = nil
    DB.set('hoods', Hoods.overrides)
    pushHood(key)
    return true
end

-- Alle Hoods für die Karte (Blips)
function Hoods.mapView()
    local out = {}
    for _, g in ipairs(Config.Gangs) do
        local h = Hoods.get({ kind = 'gang', id = g.id })
        out[#out + 1] = { key = 'gang:' .. g.id, name = h.name, team = g.name, tag = g.tag, blip = g.blip, color = g.color, x = h.spawn.x, y = h.spawn.y, z = h.spawn.z }
    end
    return out
end

-- -----------------------------------------------------------------------
--  Garage
-- -----------------------------------------------------------------------
--  An der Hood: Autos nach Level. Im Gangwar: Gangwar-Autos (für alle frei)
--  am eigenen Team-Spawn vor der Bubble.
Garage = {}

local function gwZone(p)
    local war = p.mode == 'gangwar' and p.warId and Gangwar.wars[p.warId]
    return war and war.zone or nil
end

-- kind = 'hood' erzwingt die Hood-Garage (z. B. fürs Inventar im Menü)
function Garage.view(p, kind)
    local level = Accounts.level(p.acc)
    local out = {}
    if kind ~= 'hood' and gwZone(p) then
        for _, v in ipairs(Config.Gangwar.vehicles or {}) do
            out[#out + 1] = { model = v.model, label = v.label or v.model, level = 1, unlocked = true }
        end
        return { vehicles = out, level = level, gangwar = true }
    end
    for _, v in ipairs(Config.Garage.vehicles or {}) do
        out[#out + 1] = { model = v.model, label = v.label or v.model, level = v.level or 1, unlocked = level >= (v.level or 1) }
    end
    return { vehicles = out, level = level }
end

local function nearGarage(p)
    if not p.team then return false end
    local ped = GetPlayerPed(p.src)
    if not ped or ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    local z = gwZone(p)
    if z then
        -- der Client setzt den Spawn auf die nächste Straße -> großzügiger Abstand zum groben Punkt
        local base = Util.gwSpawnBase(z, p.side)
        local dx, dy = pos.x - base.x, pos.y - base.y
        local range = Config.Gangwar.garageRange or 90.0
        return dx * dx + dy * dy <= range * range and not Util.inBubble(z, pos)
    end
    local h = Hoods.get(p.team)
    local dx, dy = pos.x - h.garage.x, pos.y - h.garage.y
    return dx * dx + dy * dy <= 15.0 * 15.0
end

local function garageMode(p)
    return p.mode == 'lobby' or gwZone(p) ~= nil
end

-- Ausgeparktes Auto eines Spielers löschen (Moduswechsel, neues Auto, Verlassen)
function Garage.cleanup(p)
    if not p or not p.vehicleNet then return end
    local ent = NetworkGetEntityFromNetworkId(p.vehicleNet)
    if ent and ent ~= 0 and DoesEntityExist(ent) then DeleteEntity(ent) end
    p.vehicleNet = nil
end

local function ownsVehicle(src, netId)
    local ent = NetworkGetEntityFromNetworkId(netId)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return nil end
    if GetEntityType(ent) ~= 2 then return false end
    return NetworkGetEntityOwner(ent) == src
end

RegisterNetEvent('bspvp:garage:spawned', function(netId)
    local src = source
    local p = Players[src]
    netId = tonumber(netId)
    if not p or not p.loggedIn or not netId or not garageMode(p) then return end
    local function remember()
        if p.vehicleNet and p.vehicleNet ~= netId then Garage.cleanup(p) end
        p.vehicleNet = netId
    end
    local ok = ownsVehicle(src, netId)
    if ok then return remember() end
    if ok == nil then                       -- Server kennt das Auto noch nicht -> gleich nochmal prüfen
        SetTimeout(1500, function()
            if Players[src] == p and ownsVehicle(src, netId) then remember() end
        end)
    end
end)

RegisterNetEvent('bspvp:garage:open', function()
    local p = Guard(source)
    if not p or not Config.Garage.enabled then return end
    if not garageMode(p) then return Notify(p.src, 'error', 'Die Garage gibt es an deiner Hood und am Gangwar-Spawn.') end
    TriggerClientEvent('bspvp:garage', p.src, Garage.view(p))
end)

RegisterNetEvent('bspvp:garage:spawn', function(model)
    local p = Guard(source)
    if not p or not Config.Garage.enabled then return end
    local gangwar = gwZone(p) ~= nil
    local v = gangwar and Util.gwVehicle(model) or (not gangwar and Util.vehicle(model))
    if not v then return Notify(p.src, 'error', 'Dieses Fahrzeug gibt es nicht.') end
    if not garageMode(p) or p.dead then return Notify(p.src, 'error', 'Ausparken geht nur an deiner Hood oder am Gangwar-Spawn.') end
    if not gangwar and Accounts.level(p.acc) < (v.level or 1) then
        return Notify(p.src, 'error', ('%s gibt es ab Level %d.'):format(v.label or v.model, v.level or 1))
    end
    if not nearGarage(p) then
        return Notify(p.src, 'error', gangwar and 'Ausparken geht nur an deinem Spawn vor der Bubble.' or 'Geh näher an die Garage.')
    end
    local wait = (p.lastVehicle + (Config.Garage.cooldown or 10) * 1000) - Now()
    if wait > 0 then
        return Notify(p.src, 'error', ('Warte noch %d Sekunden.'):format(math.ceil(wait / 1000)))
    end
    p.lastVehicle = Now()
    Garage.cleanup(p)
    local info = Teams.info(p.team)
    TriggerClientEvent('bspvp:garage:spawn', p.src, {
        model = v.model,
        label = v.label or v.model,
        color = Util.hexToRgb(info and info.color or '#ffffff'),
        plate = string.sub((info and info.tag or 'GW') .. ' ' .. p.acc.id, 1, 8),
        car = not gangwar and Hoods.get(p.team).car or nil,    -- im Gangwar sucht der Client die Straße am Spawn
        gangwar = gangwar,
    })
end)
