-- =======================================================================
--  Gangwar: Gebiete erobern
--  Ablauf: Angriff -> Vorbereitung (kein Schaden) -> Kampf -> Ergebnis
--  Jedes Gebiet ist eine Bubble auf der Straße. Die Teams spawnen auf
--  gegenüberliegenden Seiten davor, parken Autos aus und fahren rein.
--  Schaden und Punkte gibt es nur in der Bubble. Gewinnen die Angreifer,
--  gehört ihnen das Gebiet. Danach hat das Gebiet eine Abklingzeit.
-- =======================================================================

Gangwar = {
    wars = {},     -- [warId] = Krieg
    zones = {},    -- [zoneKey] = { owner = 'gang:ballas' | 'private:3' | nil, cooldownUntil = os.time }
    nextWar = 1,
}

local int = Util.int

local function refFromKey(key)
    if type(key) ~= 'string' then return nil end
    local kind, id = key:match('^(%a+):(.+)$')
    if kind == 'gang' then return { kind = 'gang', id = id } end
    if kind == 'private' then return { kind = 'private', id = int(id) } end
    return nil
end
Gangwar.refFromKey = refFromKey

local function teamView(key)
    local ref = refFromKey(key)
    local info = ref and Teams.info(ref)
    if not info then return nil end
    return { key = info.key, name = info.name, tag = info.tag, color = info.color, blip = info.blip }
end

local function warByZone(zoneKey)
    for _, war in pairs(Gangwar.wars) do
        if war.zoneKey == zoneKey then return war end
    end
    return nil
end
Gangwar.warByZone = warByZone

-- Steht der Spieler gerade in der Bubble dieses Gangwars?
function Gangwar.inBubble(war, src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return Util.inBubble(war.zone, GetEntityCoords(ped), 5.0)
end

-- -----------------------------------------------------------------------
--  Speichern & Laden
-- -----------------------------------------------------------------------
function Gangwar.loadZones()
    local saved = DB.get('zones')
    if type(saved) ~= 'table' then saved = {} end
    for _, z in ipairs(Config.Zones) do
        local s = saved[z.key]
        local owner
        if type(s) == 'table' then
            owner = s.owner or nil               -- false = neutral
        elseif z.owner then
            owner = 'gang:' .. z.owner           -- Startbesitzer aus der Config
        end
        if owner and not teamView(owner) then owner = nil end
        Gangwar.zones[z.key] = {
            owner = owner,
            cooldownUntil = type(s) == 'table' and int(s.cooldownUntil) or 0,
        }
    end
end

function Gangwar.saveZones()
    local out = {}
    for key, s in pairs(Gangwar.zones) do
        out[key] = { owner = s.owner or false, cooldownUntil = s.cooldownUntil or 0 }
    end
    DB.set('zones', out)
end

function Gangwar.ownedCount(teamKey)
    if not teamKey then return 0 end
    local n = 0
    for _, s in pairs(Gangwar.zones) do
        if s.owner == teamKey then n = n + 1 end
    end
    return n
end

function Gangwar.clearOwner(teamKey)
    local changed = false
    for _, s in pairs(Gangwar.zones) do
        if s.owner == teamKey then
            s.owner = nil
            changed = true
        end
    end
    if changed then
        Gangwar.saveZones()
        Gangwar.pushMap()
    end
end

function Gangwar.teamInWar(teamKey)
    if not teamKey then return false end
    for _, war in pairs(Gangwar.wars) do
        if war.phase ~= 'ended' and (war.attacker == teamKey or war.defender == teamKey) then return true end
    end
    return false
end

-- -----------------------------------------------------------------------
--  Anzeige
-- -----------------------------------------------------------------------
function Gangwar.statePayload(war)
    local function side(key, name)
        local v = teamView(key)
        if not v then return nil end
        local count = 0
        for _, s in pairs(war.players) do
            if s == name then count = count + 1 end
        end
        return {
            name = v.name, tag = v.tag, color = v.color,
            points = war.points[name], kills = war.kills[name], players = count,
        }
    end
    return {
        id = war.id,
        zone = war.zoneKey,
        zoneName = war.zone.name,
        phase = war.phase,
        remaining = math.max(0, math.ceil((war.phaseEndsAt - Now()) / 1000)),
        attacker = side(war.attacker, 'attacker'),
        defender = side(war.defender, 'defender'),
        winner = war.winner,
    }
end

function Gangwar.broadcastState(war)
    local payload = Gangwar.statePayload(war)
    for src in pairs(war.players) do
        TriggerClientEvent('bspvp:war', src, payload)
    end
end

function Gangwar.sendState(p)
    local war = p.warId and Gangwar.wars[p.warId]
    TriggerClientEvent('bspvp:war', p.src, war and Gangwar.statePayload(war) or false)
end

-- Besitzer aller Gebiete für die Karte
function Gangwar.mapView()
    local out = {}
    for _, z in ipairs(Config.Zones) do
        local s = Gangwar.zones[z.key] or {}
        local owner = teamView(s.owner)
        out[#out + 1] = {
            key = z.key,
            owner = owner and { name = owner.name, tag = owner.tag, color = owner.color, blip = owner.blip } or nil,
            war = warByZone(z.key) ~= nil,
        }
    end
    return out
end

function Gangwar.pushMap()
    local view = Gangwar.mapView()
    for _, p in pairs(Players) do
        if p.loggedIn then TriggerClientEvent('bspvp:zones', p.src, view) end
    end
end

-- -----------------------------------------------------------------------
--  Angreifen & Beitreten
-- -----------------------------------------------------------------------
function Gangwar.canAttack(p, zoneKey)
    local z = Util.zone(zoneKey)
    if not z then return false, 'Dieses Gebiet gibt es nicht.' end
    if not p.team then return false, 'Wähle zuerst ein Team.' end
    if p.mode ~= 'lobby' and p.mode ~= 'ffa' then return false, 'Angreifen geht von deiner Hood oder aus dem FFA.' end
    local myKey = Teams.key(p.team)
    local s = Gangwar.zones[zoneKey]
    if s.owner == myKey then return false, 'Das Gebiet gehört schon deinem Team.' end
    if warByZone(zoneKey) then return false, 'Um dieses Gebiet wird schon gekämpft.' end
    if Gangwar.teamInWar(myKey) then return false, 'Dein Team ist schon in einem Gangwar.' end
    if s.owner and Gangwar.teamInWar(s.owner) then return false, 'Die Verteidiger kämpfen gerade woanders.' end
    local left = (s.cooldownUntil or 0) - os.time()
    if left > 0 then
        return false, ('Abklingzeit: noch %d:%02d'):format(left // 60, left % 60)
    end
    if p.team.kind == 'private' and Config.Gangwar.privateLeaderOnly then
        local t = Teams.private[int(p.team.id)]
        if not t or t.leader ~= p.acc.id then return false, 'Nur der Team-Leader darf angreifen.' end
    end
    local need = Config.Gangwar.minDefendersOnline or 0
    if s.owner and need > 0 and Teams.online(refFromKey(s.owner)) < need then
        return false, ('Es müssen mindestens %d Verteidiger online sein.'):format(need)
    end
    return true
end

function Gangwar.join(p, zoneKey)
    local war = warByZone(zoneKey)
    if not war or war.phase == 'ended' then
        return Notify(p.src, 'error', 'Hier läuft gerade kein Gangwar.')
    end
    local myKey = Teams.key(p.team)
    local side
    if myKey and myKey == war.attacker then
        side = 'attacker'
    elseif myKey and war.defender and myKey == war.defender then
        side = 'defender'
    end
    if not side then
        return Notify(p.src, 'error', 'Dein Team ist an diesem Gangwar nicht beteiligt.')
    end
    if p.mode == 'gangwar' and p.warId == war.id then return end
    if p.mode ~= 'lobby' and p.mode ~= 'ffa' and p.mode ~= 'gangwar' then
        return Notify(p.src, 'error', 'Wähle zuerst ein Team.')
    end
    if p.mode == 'gangwar' then Gangwar.removePlayer(p) end

    p.warId, p.side = war.id, side
    war.players[p.src] = side
    war.participants[p.acc.id] = side
    Modes.set(p, 'gangwar')
    Gangwar.broadcastState(war)
    Notify(p.src, 'war', ('%s: Park dir am Spawn mit %s ein Auto aus und fahr in die Bubble. Nur dort wird gekämpft.'):format(
        war.zone.name, Config.Keys.interact or 'E'))
end

function Gangwar.attack(p, zoneKey)
    local ok, reason = Gangwar.canAttack(p, zoneKey)
    if not ok then return Notify(p.src, 'error', reason) end

    local z = Util.zone(zoneKey)
    local s = Gangwar.zones[zoneKey]
    local id = Gangwar.nextWar
    Gangwar.nextWar = id + 1

    local war = {
        id = id,
        zoneKey = zoneKey,
        zone = z,
        attacker = Teams.key(p.team),
        defender = s.owner,
        phase = 'prepare',
        phaseEndsAt = Now() + (Config.Gangwar.prepareSeconds or 60) * 1000,
        points = { attacker = Config.Gangwar.attackerStartPoints or 0, defender = 0 },
        kills = { attacker = 0, defender = 0 },
        players = {},        -- [source] = side (gerade im Krieg)
        participants = {},   -- [userId] = side (für Belohnungen)
    }
    Gangwar.wars[id] = war
    SetRoutingBucketPopulationEnabled(1000 + id, false)

    local att, def = teamView(war.attacker), teamView(war.defender)
    Logs.add('gangwar', ('%s startet einen Angriff auf **%s**'):format(Logs.who(p), z.name), {
        { 'Angreifer', att and att.name or '?', true }, { 'Verteidiger', def and def.name or 'Frei', true },
    })
    if def then
        Announce(-1, ('%s greift %s an!'):format(att.name, z.name))
        Chat(-1, ('^1Gangwar:^7 %s greift ^3%s^7 (%s) an!'):format(att.name, z.name, def.name))
    else
        Announce(-1, ('%s besetzt das freie Gebiet %s'):format(att.name, z.name))
    end
    for _, q in pairs(Players) do
        if q.loggedIn and q ~= p then
            local key = Teams.key(q.team)
            if key == war.attacker then
                Notify(q.src, 'war', ('Euer Team greift %s an! Drück F2 und tritt unter Gangwar bei.'):format(z.name))
            elseif def and key == war.defender then
                Notify(q.src, 'war', ('Euer Gebiet %s wird angegriffen! Drück F2 und verteidige es unter Gangwar.'):format(z.name))
            end
        end
    end

    Gangwar.join(p, zoneKey)
    Gangwar.pushMap()
end

function Gangwar.removePlayer(p)
    local war = p.warId and Gangwar.wars[p.warId]
    p.warId, p.side = nil, nil
    if war then
        war.players[p.src] = nil
        Gangwar.broadcastState(war)
    end
    TriggerClientEvent('bspvp:war', p.src, false)
end

-- Kill im Gangwar -> Punkte (nur in der Bubble, nur gegen das andere Team)
function Gangwar.onKill(killer, victim)
    local war = killer.warId and Gangwar.wars[killer.warId]
    if not war or war.phase ~= 'fight' or victim.warId ~= war.id then return end
    if not killer.side or killer.side == victim.side then return end
    if not Gangwar.inBubble(war, victim.src) then return end
    war.points[killer.side] = war.points[killer.side] + (Config.Gangwar.pointsPerKill or 1)
    war.kills[killer.side] = war.kills[killer.side] + 1
    Gangwar.broadcastState(war)
end

-- -----------------------------------------------------------------------
--  Ende eines Gangwars
-- -----------------------------------------------------------------------
local function finish(war, winner)
    war.phase = 'ended'
    war.winner = winner
    war.phaseEndsAt = Now() + 10000      -- 10 s Ergebnis, dann zurück in die Lobby

    local s = Gangwar.zones[war.zoneKey]
    local captured = winner == 'attacker'
    if captured then s.owner = war.attacker end
    s.cooldownUntil = os.time() + (Config.Gangwar.cooldownMinutes or 30) * 60
    Gangwar.saveZones()

    -- Volle Sieg-Belohnung nur, wenn wirklich gekämpft wurde (kein Farmen leerer Gebiete)
    local contested = false
    for _, side in pairs(war.participants) do
        if side == 'defender' then contested = true break end
    end

    for uid, side in pairs(war.participants) do
        local acc = Accounts.get(uid)
        if acc then
            local won = side == winner
            local r = (won and contested) and Config.Rewards.gangwarWin or Config.Rewards.gangwarLoss
            acc.stats.gwPlayed = acc.stats.gwPlayed + 1
            if won then acc.stats.gwWins = acc.stats.gwWins + 1 end
            Missions.track(acc, 'gwPlayed', 1)
            if won then Missions.track(acc, 'gwWin', 1) end
            Accounts.addMoney(acc, r.money or 0)
            local p = PlayerByUserId(uid)
            if p then
                Accounts.addXp(p, r.xp or 0)
                Accounts.push(p)
                Notify(p.src, won and 'success' or 'info', ('%s: +$%s und +%d XP'):format(
                    won and 'Gangwar gewonnen' or 'Gangwar verloren', Util.formatMoney(r.money or 0), r.xp or 0))
            else
                acc.xp = acc.xp + int(r.xp)
            end
            Accounts.save(acc)
        end
    end

    local att, def = teamView(war.attacker), teamView(war.defender)
    local text
    if captured then
        if def then
            text = ('%s erobert %s von %s!'):format(att and att.name or '?', war.zone.name, def.name)
        else
            text = ('%s erobert %s!'):format(att and att.name or '?', war.zone.name)
        end
    else
        text = ('%s verteidigt %s!'):format(def and def.name or '?', war.zone.name)
    end
    Announce(-1, text)
    Chat(-1, '^1Gangwar:^7 ' .. text)
    Logs.add('gangwar', text, {
        { 'Punkte', ('%d : %d'):format(war.points.attacker, war.points.defender), true },
        { 'Kills', ('%d : %d'):format(war.kills.attacker, war.kills.defender), true },
    })
    Gangwar.broadcastState(war)
    for src in pairs(war.players) do
        TriggerClientEvent('bspvp:warEnd', src, { winner = winner, text = text })
    end
    Gangwar.pushMap()
end

-- Admin: Krieg sofort beenden
function Gangwar.forceEnd(zoneKey)
    local war = warByZone(zoneKey)
    if not war or war.phase == 'ended' then return false end
    finish(war, war.points.attacker > war.points.defender and 'attacker' or 'defender')
    return true
end

-- Admin: Besitzer setzen (teamKey = nil -> frei)
function Gangwar.setOwner(zoneKey, teamKey)
    local s = Gangwar.zones[zoneKey]
    if not s then return false end
    if teamKey and not teamView(teamKey) then return false end
    s.owner = teamKey
    s.cooldownUntil = 0
    Gangwar.saveZones()
    Gangwar.pushMap()
    return true
end

-- -----------------------------------------------------------------------
--  Menü-Daten
-- -----------------------------------------------------------------------
function Gangwar.menuView(p)
    local myKey = Teams.key(p.team)
    local out = {}
    for _, z in ipairs(Config.Zones) do
        local s = Gangwar.zones[z.key]
        local war = warByZone(z.key)
        local entry = {
            key = z.key,
            name = z.name,
            x = z.center.x,
            y = z.center.y,
            radius = z.radius,
            owner = teamView(s.owner),
            mine = s.owner ~= nil and s.owner == myKey,
            cooldown = math.max(0, (s.cooldownUntil or 0) - os.time()),
        }
        if war then
            entry.war = Gangwar.statePayload(war)
            if myKey == war.attacker then entry.war.mySide = 'attacker'
            elseif war.defender and myKey == war.defender then entry.war.mySide = 'defender' end
            entry.war.inside = p.warId == war.id
        end
        entry.canAttack, entry.reason = Gangwar.canAttack(p, z.key)
        out[#out + 1] = entry
    end
    return out
end

-- -----------------------------------------------------------------------
--  Ablauf-Timer & Gebietseinkommen
-- -----------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(1000)
        local t = Now()
        for id, war in pairs(Gangwar.wars) do
            if war.phase == 'prepare' and t >= war.phaseEndsAt then
                if not war.defender then
                    finish(war, 'attacker')                     -- freies Gebiet
                else
                    war.phase = 'fight'
                    war.phaseEndsAt = t + (Config.Gangwar.fightMinutes or 10) * 60000
                    Gangwar.broadcastState(war)
                    for src in pairs(war.players) do
                        Announce(src, ('Kampf um %s!'):format(war.zone.name))
                    end
                end
            elseif war.phase == 'fight' and t >= war.phaseEndsAt then
                finish(war, war.points.attacker > war.points.defender and 'attacker' or 'defender')
            elseif war.phase == 'ended' and t >= war.phaseEndsAt then
                Gangwar.wars[id] = nil
                for src in pairs(war.players) do
                    local p = Players[src]
                    if p and p.warId == id then Modes.set(p, 'lobby') end
                end
                Gangwar.pushMap()
            end
        end
    end
end)

CreateThread(function()
    local minutes = Config.Gangwar.incomeMinutes or 0
    if minutes <= 0 then return end
    while true do
        Wait(minutes * 60000)
        local owned = {}
        for _, s in pairs(Gangwar.zones) do
            if s.owner then owned[s.owner] = (owned[s.owner] or 0) + 1 end
        end
        for _, p in pairs(Players) do
            local key = p.loggedIn and Teams.key(p.team)
            local n = key and owned[key]
            if n and n > 0 then
                local amount = n * (Config.Gangwar.incomePerZone or 0)
                Accounts.addMoney(p.acc, amount)
                Accounts.save(p.acc)
                Accounts.push(p)
                Notify(p.src, 'success', ('Gebietseinkommen: +$%s (%d %s)'):format(
                    Util.formatMoney(amount), n, n == 1 and 'Gebiet' or 'Gebiete'))
            end
        end
    end
end)

-- -----------------------------------------------------------------------
--  Client -> Server
-- -----------------------------------------------------------------------
RegisterNetEvent('bspvp:gwAttack', function(zoneKey)
    local p = Guard(source)
    if not p then return end
    Gangwar.attack(p, tostring(zoneKey))
end)

RegisterNetEvent('bspvp:gwJoin', function(zoneKey)
    local p = Guard(source)
    if not p then return end
    Gangwar.join(p, tostring(zoneKey))
end)
