-- =======================================================================
--  Anticheat (läuft auf dem Server – der Client kann es nicht abschalten)
--
--  Erkennt:
--   - Explosionen (gibt es auf diesem Server nicht)
--   - Waffen in der Hand, die man nicht besitzt (RPG, Minigun, Pistolen …)
--   - Schaden mit nicht gekauften Waffen / Schießen, obwohl man tot ist
--   - Teleport & Speedhack (zu große Strecke pro Sekunde)
--   - selbst gespawnte NPCs und verbotene Fahrzeuge, Objekt-Spam
--   - Admin-Aktionen ohne Admin-Recht
--   - gestoppte Skripte beim Spieler (fehlender Herzschlag)
--  Jede Erkennung geht in den Anticheat-Webhook. Was passiert, steht in
--  Config.AntiCheat ('log', 'kick' oder 'ban').
-- =======================================================================

AntiCheat = { strikes = {}, grace = {}, lastBeat = {}, objects = {} }

local AC = Config.AntiCheat or {}
local UNARMED = Weapons.toUnsigned(GetHashKey('WEAPON_UNARMED'))
local SAFE_WEAPONS = {
    [UNARMED] = true,
    [Weapons.toUnsigned(GetHashKey('GADGET_PARACHUTE'))] = true,
    [Weapons.toUnsigned(GetHashKey('WEAPON_OBJECT'))] = true,
}

local function enabled() return AC.enabled ~= false end

-- Nach Teleports, Spawns und Admin-Trolls kurz keine Bewegungsprüfung
function AntiCheat.allowMove(src, seconds)
    AntiCheat.grace[src] = GetGameTimer() + math.floor((seconds or 6) * 1000)
end

local function inGrace(src)
    return (AntiCheat.grace[src] or 0) > GetGameTimer()
end

-- Erkennung melden und je nach Einstellung handeln
function AntiCheat.flag(src, kind, detail, action)
    if not enabled() then return end
    src = tonumber(src)
    if not src or src <= 0 or not GetPlayerName(src) then return end
    action = action or AC[kind] or 'log'

    -- 'log'-Erkennungen zählen (pro Art): zu viele in 10 Minuten = Kick
    if action == 'log' then
        AntiCheat.strikes[src] = AntiCheat.strikes[src] or {}
        local list = AntiCheat.strikes[src][kind] or {}
        local now = os.time()
        local keep = {}
        for _, t in ipairs(list) do if now - t < 600 then keep[#keep + 1] = t end end
        keep[#keep + 1] = now
        AntiCheat.strikes[src][kind] = keep
        -- Teleport-Meldungen zählen erst ab 5 (Lag kann mal einen Sprung erzeugen)
        local need = kind == 'teleport' and (AC.teleportStrikes or 5) or (AC.strikesBeforeAction or 3)
        if #keep >= need then
            action = 'kick'
            AntiCheat.strikes[src][kind] = {}
        end
    end

    local p = Players[src]
    local what = ({ log = 'Nur gemeldet', kick = 'Gekickt', ban = 'Gebannt' })[action] or action
    Logs.add('ac', ('**%s** – %s'):format(kind, Logs.who(p or src)), {
        { 'Erkennung', kind, true },
        { 'Aktion', what, true },
        { 'Ort', p and Progress.placeName(p) or '–', true },
        { 'Details', detail or '–' },
        { 'Kennungen', Logs.ids(src) ~= '' and Logs.ids(src) or '–' },
    })
    print(('^1[Anticheat] %s: %s (%s) -> %s^7'):format(GetPlayerName(src) or src, kind, detail or '', what))

    if action == 'ban' then
        if p and p.acc then
            Admin.ban(0, p.acc, AC.banHours or 0, 'Anticheat: ' .. kind, 'Anticheat')
        else
            DropPlayer(src, 'Anticheat: ' .. kind)
        end
    elseif action == 'kick' then
        DropPlayer(src, ('Du wurdest vom Anticheat gekickt (%s). Melde dich im Discord, falls das ein Fehler war.'):format(kind))
    end
end

-- -----------------------------------------------------------------------
--  Explosionen: alle blockieren (niemand bekommt Schaden davon)
--  Bann nur für Waffen-Explosionen (Granate, Rakete, Molotow …) – die kann
--  auf diesem Server niemand ohne Cheat auslösen. Ein explodierendes Auto
--  ist normal und wird nur bei Spam (Mod-Menü) gemeldet.
-- -----------------------------------------------------------------------
local WEAPON_EXPLOSIONS = {}
-- 0 Granate, 1 Granatwerfer, 2 Haftbombe, 3 Molotow, 4 Rakete, 5 Panzer, 18 Explosivmunition,
-- 19-21 Rauch/Gas, 22 Leuchtpistole, 25 Prog. AR, 32/33 Fahrzeugwaffen, 36 Railgun, 38 Feuerwerk,
-- 40 Annäherungsmine, 41-65 Militär-/Fahrzeugwaffen, 70 Raygun, 72 Skript-Rakete, 73 RC-Panzer
for _, t in ipairs({ 0, 1, 2, 3, 4, 5, 18, 19, 20, 21, 22, 25, 32, 33, 36, 38, 40, 41, 43, 44, 45, 46, 47, 48, 49, 50, 51,
                     53, 55, 56, 57, 59, 60, 61, 62, 63, 64, 65, 70, 72, 73 }) do
    WEAPON_EXPLOSIONS[t] = true
end
local explosionCount = {}

AddEventHandler('explosionEvent', function(sender, ev)
    if not enabled() then return end
    CancelEvent()
    sender = tonumber(sender)
    if not sender then return end
    local kind = tonumber(ev and ev.explosionType) or -1
    if WEAPON_EXPLOSIONS[kind] then
        return AntiCheat.flag(sender, 'explosion', ('Waffen-Explosion Typ %d'):format(kind))
    end
    if ev and (ev.isInvisible == true or ev.isAudible == false) then
        return AntiCheat.flag(sender, 'explosion', ('unsichtbare/lautlose Explosion Typ %d'):format(kind), 'kick')
    end
    local now = os.time()
    local e = explosionCount[sender]
    if not e or now - e.since > 10 then e = { since = now, n = 0 } end
    e.n = e.n + 1
    explosionCount[sender] = e
    if e.n == 5 then
        AntiCheat.flag(sender, 'explosion', ('%d Explosionen in 10 s (Typ %d)'):format(e.n, kind), 'kick')
    end
end)

-- -----------------------------------------------------------------------
--  Netzwerk-Events, die nur Cheats auslösen (gegen ANDERE Spieler)
-- -----------------------------------------------------------------------
local function targetsOther(sender, netId)
    local ent = tonumber(netId) and NetworkGetEntityFromNetworkId(tonumber(netId)) or 0
    if not ent or ent == 0 then return false end
    return ent ~= GetPlayerPed(tonumber(sender))
end

AddEventHandler('giveWeaponEvent', function(sender, data)
    if not enabled() then return end
    CancelEvent()
    if targetsOther(sender, data and data.pedId) then
        AntiCheat.flag(sender, 'giveWeapon', 'hat einem anderen Spieler eine Waffe gegeben (Mod-Menü)', 'ban')
    end
end)

AddEventHandler('removeWeaponEvent', function(sender, data)
    if not enabled() then return end
    if targetsOther(sender, data and data.pedId) then
        CancelEvent()
        AntiCheat.flag(sender, 'removeWeapon', 'hat einem anderen Spieler die Waffe weggenommen', 'kick')
    end
end)

AddEventHandler('removeAllWeaponsEvent', function(sender, data)
    if not enabled() then return end
    if targetsOther(sender, data and data.pedId) then
        CancelEvent()
        AntiCheat.flag(sender, 'removeWeapon', 'hat einem anderen Spieler alle Waffen weggenommen', 'kick')
    end
end)

AddEventHandler('clearPedTasksEvent', function(sender, data)
    if not enabled() then return end
    if targetsOther(sender, data and data.pedId) then
        CancelEvent()
        AntiCheat.flag(sender, 'clearTasks', 'hat einen anderen Spieler eingefroren / aus dem Auto geworfen', 'log')
    end
end)

-- Geschosse (Raketen, Granaten): mit den Gewehren hier gibt es keine
AddEventHandler('startProjectileEvent', function(sender, data)
    if not enabled() then return end
    CancelEvent()
    AntiCheat.flag(sender, 'projectile', ('Geschoss abgefeuert (Waffe %s)'):format(tostring(data and data.weaponHash)), 'kick')
end)

-- Partikel-Effekte & Feuer: blocken, bei Spam melden
local spam = {}
local function spamCheck(sender, kind, limit, action)
    sender = tonumber(sender)
    if not sender then return end
    local now = os.time()
    local key = kind .. ':' .. sender
    local s = spam[key]
    if not s or now - s.since > 10 then s = { since = now, n = 0 } end
    s.n = s.n + 1
    spam[key] = s
    if s.n == limit then AntiCheat.flag(sender, kind, ('%d in 10 Sekunden'):format(limit), action) end
end
AddEventHandler('ptFxEvent', function(sender)
    if not enabled() then return end
    CancelEvent()
    spamCheck(sender, 'particleSpam', 15, 'kick')
end)
-- brennende Autos erzeugen auch Feuer -> nur melden (3 Meldungen = Kick)
AddEventHandler('fireEvent', function(sender)
    if not enabled() then return end
    CancelEvent()
    spamCheck(sender, 'fireSpam', 15, 'log')
end)

-- -----------------------------------------------------------------------
--  Unsichtbar (alle 2 s, zweimal hintereinander, nur wenn man lebt)
-- -----------------------------------------------------------------------
local invisible = {}
CreateThread(function()
    while true do
        Wait(2000)
        if enabled() and IsEntityVisible then
            for src, p in pairs(Players) do
                local ped = GetPlayerPed(src)
                if p.loggedIn and not p.dead and p.mode ~= 'select' and ped and ped ~= 0 and not inGrace(src) then
                    if not IsEntityVisible(ped) then
                        invisible[src] = (invisible[src] or 0) + 1
                        if invisible[src] == 3 then AntiCheat.flag(src, 'invisible', 'seit 6 Sekunden unsichtbar', 'kick') end
                    else
                        invisible[src] = 0
                    end
                end
            end
        end
    end
end)

-- -----------------------------------------------------------------------
--  Fremde Waffen in der Hand (alle 2 Sekunden, zweimal hintereinander)
-- -----------------------------------------------------------------------
local weaponHits = {}
local function allowedWeapon(p, hash)
    local u = Weapons.toUnsigned(hash)
    if not u or SAFE_WEAPONS[u] then return true end
    local w = Weapons.byHash[u]
    if not w then return false end
    if p.mode == 'duel' then return Duels.weaponOf(p) == w.name end
    return Accounts.owns(p.acc, w.name)
end

CreateThread(function()
    while true do
        Wait(2000)
        if enabled() and AC.weapon ~= false then
            for src, p in pairs(Players) do
                if p.loggedIn and p.acc and not p.dead then
                    local ped = GetPlayerPed(src)
                    if ped and ped ~= 0 then
                        local hash = GetSelectedPedWeapon(ped)
                        if not allowedWeapon(p, hash) then
                            weaponHits[src] = (weaponHits[src] or 0) + 1
                            if weaponHits[src] >= 2 then
                                weaponHits[src] = 0
                                RemoveAllPedWeapons(ped, true)
                                AntiCheat.flag(src, 'weapon', ('Waffe %s in der Hand, nicht im Besitz'):format(tostring(Weapons.toUnsigned(hash))))
                            end
                        else
                            weaponHits[src] = 0
                        end
                    end
                end
            end
        end
    end
end)

-- -----------------------------------------------------------------------
--  Teleport / Speedhack (jede Sekunde)
-- -----------------------------------------------------------------------
local lastPos = {}
CreateThread(function()
    while true do
        Wait(1000)
        if enabled() and AC.teleport ~= false then
            local now = GetGameTimer()
            for src, p in pairs(Players) do
                local ped = GetPlayerPed(src)
                if p.loggedIn and not p.dead and ped and ped ~= 0 and p.mode ~= 'select' then
                    local pos = GetEntityCoords(ped)
                    local last = lastPos[src]
                    if last and not inGrace(src) then
                        local dt = math.max(0.5, (now - last.t) / 1000)
                        local dist = #(pos - last.pos)
                        local veh = GetVehiclePedIsIn(ped, false)
                        local limit = (veh and veh ~= 0) and (AC.speedVehicle or 130.0) or (AC.speedOnFoot or 40.0)
                        if dist / dt > limit and dist > 60.0 then
                            AntiCheat.flag(src, 'teleport', ('%.0f m in %.1f s (%s)'):format(dist, dt, (veh and veh ~= 0) and 'im Fahrzeug' or 'zu Fuß'))
                        end
                    end
                    lastPos[src] = { pos = pos, t = now }
                else
                    lastPos[src] = nil
                end
            end
        end
    end
end)

-- Client meldet einen eigenen Teleport (Zonen-Grenze) – höchstens alle 8 s
local lastSelfTp = {}
RegisterNetEvent('bspvp:ac:tp', function()
    local src = source
    local t = GetGameTimer()
    if t - (lastSelfTp[src] or -100000) < 8000 then return end
    lastSelfTp[src] = t
    AntiCheat.allowMove(src, 5)
end)

-- -----------------------------------------------------------------------
--  Gespawnte Entities
-- -----------------------------------------------------------------------
local allowedVehicles = {}
for _, v in ipairs(Config.Garage.vehicles or {}) do allowedVehicles[GetHashKey(v.model)] = true end
for _, v in ipairs(Config.Gangwar.vehicles or {}) do allowedVehicles[GetHashKey(v.model)] = true end

AddEventHandler('entityCreating', function(entity)
    if not enabled() then return end
    local owner = NetworkGetEntityOwner(entity)
    if not owner or owner <= 0 or not Players[owner] then return end
    local kind = GetEntityType(entity)
    local scripted = GetEntityPopulationType(entity) == 7        -- 7 = von einem Skript erstellt
    if kind == 1 and scripted and AC.entity ~= false then
        CancelEvent()
        AntiCheat.flag(owner, 'entity', ('NPC gespawnt (Modell %s)'):format(tostring(GetEntityModel(entity))))
    elseif kind == 2 and scripted and AC.entity ~= false and not allowedVehicles[GetEntityModel(entity)] then
        CancelEvent()
        AntiCheat.flag(owner, 'entity', ('verbotenes Fahrzeug gespawnt (Modell %s)'):format(tostring(GetEntityModel(entity))))
    elseif kind == 3 and scripted then
        local now = os.time()
        local o = AntiCheat.objects[owner]
        if not o or now - o.since > 10 then o = { since = now, n = 0 } end
        o.n = o.n + 1
        AntiCheat.objects[owner] = o
        if o.n > (AC.objectsPer10s or 25) then
            CancelEvent()
            if o.n == (AC.objectsPer10s or 25) + 1 then
                AntiCheat.flag(owner, 'entity', ('Objekt-Spam: über %d Objekte in 10 s'):format(AC.objectsPer10s or 25))
            end
        end
    end
end)

-- -----------------------------------------------------------------------
--  Herzschlag: das Skript muss beim Spieler laufen
-- -----------------------------------------------------------------------
-- Herzschlag mit der Liste der Resourcen beim Spieler: eingeschleuste
-- Resourcen (Executor/Mod-Menü) gibt es auf dem Server nicht
local checkedResources = {}
RegisterNetEvent('bspvp:ac:beat', function(resources)
    local src = source
    AntiCheat.lastBeat[src] = os.time()
    if type(resources) ~= 'table' or checkedResources[src] == #resources then return end
    checkedResources[src] = #resources
    for i, name in ipairs(resources) do
        if i > 200 then break end
        name = tostring(name)
        if name:sub(1, 1) ~= '_' and GetResourceState(name) == 'missing' then
            AntiCheat.flag(src, 'injection', ('fremde Resource "%s" beim Spieler'):format(name:sub(1, 48)), 'kick')
            return
        end
    end
end)

CreateThread(function()
    while true do
        Wait(15000)
        if enabled() and AC.heartbeat ~= false then
            local now = os.time()
            local limit = AC.heartbeatSeconds or 90
            for src, p in pairs(Players) do
                if p.loggedIn then
                    local last = AntiCheat.lastBeat[src]
                    if not last then
                        AntiCheat.lastBeat[src] = now               -- erste Runde: Zeit geben
                    elseif now - last > limit then
                        AntiCheat.lastBeat[src] = now
                        AntiCheat.flag(src, 'heartbeat', ('seit %d s kein Lebenszeichen vom Client-Skript'):format(now - last))
                    end
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    AntiCheat.strikes[src], AntiCheat.grace[src], AntiCheat.lastBeat[src] = nil, nil, nil
    AntiCheat.objects[src], lastPos[src], weaponHits[src], lastSelfTp[src] = nil, nil, nil, nil
    explosionCount[src], invisible[src], checkedResources[src] = nil, nil, nil
end)
