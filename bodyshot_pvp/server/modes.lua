-- =======================================================================
--  Modi: Hood (Lobby), FFA, Gangwar
--  Jeder Modus läuft in einer eigenen Welt (Routing-Bucket):
--    Hood/Lobby = 0, FFA-Arena i = 100 + i, jeder Gangwar = 1000 + Kriegs-ID,
--    jedes 1v1-Duell = 3000 + Duell-ID, Login/Teamauswahl = 5000 + Spieler (allein)
-- =======================================================================

Modes = {}
FFA = {}

local int = Util.int
local BUCKET_LOBBY = 0

function FFA.bucket(index) return 100 + int(index) end

function Modes.bucketFor(p)
    if p.mode == 'lobby' then return BUCKET_LOBBY end
    if p.mode == 'ffa' and p.arena then return FFA.bucket(p.arena) end
    if p.mode == 'gangwar' and p.warId then return 1000 + p.warId end
    if p.mode == 'duel' and p.duelId then return Duels.bucket(p.duelId) end
    return 5000 + p.src
end

-- Regeln je Modus: Respawn-Zeit, Heilung pro Kill, Geld/XP pro Kill
function Modes.rules(p)
    if p.mode == 'ffa' then
        return { respawn = Config.FFA.respawnSeconds, killReward = Config.FFA.killReward, reward = Config.Rewards.ffaKill, combat = true }
    elseif p.mode == 'gangwar' then
        return { respawn = Config.Gangwar.respawnSeconds, killReward = Config.Gangwar.killReward, reward = Config.Rewards.gangwarKill, combat = true }
    elseif p.mode == 'duel' then
        return { respawn = 3, combat = true }                -- neue Runde startet der Duell-Takt
    elseif p.mode == 'lobby' and Config.HoodCombat then
        return { respawn = Config.HoodRespawnSeconds or 3, reward = Config.Rewards.hoodKill, combat = true }
    end
    return { respawn = 1, combat = false }
end

-- Sehen sich zwei Spieler gerade in derselben Welt?
function Modes.sameWorldAs(a, b)
    if not a.loggedIn or not b.loggedIn or a.mode ~= b.mode then return false end
    if a.mode == 'ffa' then return a.arena == b.arena end
    if a.mode == 'gangwar' then return a.warId == b.warId end
    if a.mode == 'duel' then return a.duelId ~= nil and a.duelId == b.duelId end
    return true
end

-- Alle Spieler, die gerade dieselbe Welt sehen (für Killfeed & Ansagen)
function Modes.sameWorld(p)
    local out = {}
    for _, q in pairs(Players) do
        if Modes.sameWorldAs(p, q) then out[#out + 1] = q end
    end
    return out
end

function Modes.broadcast(p, event, ...)
    for _, q in ipairs(Modes.sameWorld(p)) do
        TriggerClientEvent(event, q.src, ...)
    end
end

function Modes.count(mode)
    local n = 0
    for _, q in pairs(Players) do
        if q.loggedIn and q.mode == mode then n = n + 1 end
    end
    return n
end

function FFA.count(index)
    local n = 0
    for _, q in pairs(Players) do
        if q.loggedIn and q.mode == 'ffa' and q.arena == index then n = n + 1 end
    end
    return n
end

function FFA.list(p)
    local out = {}
    for i, a in ipairs(Config.Arenas) do
        out[#out + 1] = {
            index = i, key = a.key or ('arena' .. i), name = a.name,
            players = FFA.count(i), max = a.max or 0,
            inside = p and p.mode == 'ffa' and p.arena == i or false,
            x = a.center.x + 0.0, y = a.center.y + 0.0, radius = (a.radius or 60) + 0.0,
        }
    end
    return out
end

-- Alle gekauften Waffen bleiben immer im Inventar: an der Hood, im FFA und im Gangwar
local function loadout(p)
    if p.mode == 'duel' then return { Duels.weaponOf(p) } end    -- beide dieselbe Waffe
    if p.mode ~= 'ffa' and p.mode ~= 'gangwar' and p.mode ~= 'lobby' then return {} end
    local out = {}
    for _, w in ipairs(Weapons.list) do
        if Accounts.owns(p.acc, w.name) then out[#out + 1] = w.name end
    end
    return out
end

-- Team-Infos als State-Bag, damit Clients Teamkameraden markieren können
function Modes.syncState(p)
    local info = Teams.info(p.team)
    local state = Player(p.src).state
    state:set('gwMode', p.mode, true)
    state:set('gwWar', p.warId or false, true)
    state:set('gwArena', p.arena or false, true)
    state:set('gwTeam', info and info.key or false, true)
    state:set('gwTag', info and info.tag or false, true)
    state:set('gwColor', info and info.color or false, true)
    state:set('gwBlip', info and info.blip or false, true)
    state:set('gwUid', p.acc and p.acc.id or false, true)
    state:set('gwName', p.acc and p.acc.name or false, true)
end

function Modes.payload(p)
    local team = Teams.info(p.team)
    local data = {
        mode = p.mode,
        respawn = Modes.rules(p).respawn,
        weapons = loadout(p),
        uid = p.acc and p.acc.id or 0,
        team = team and {
            key = team.key, kind = team.kind, id = team.id, name = team.name, tag = team.tag,
            color = team.color, outfit = team.outfit,
        } or nil,
        hood = p.team and Hoods.get(p.team) or nil,
    }
    if p.mode == 'ffa' then
        data.arena = p.arena
    elseif p.mode == 'gangwar' then
        local war = Gangwar.wars[p.warId]
        if war then
            data.zone = war.zoneKey
            data.side = p.side
            data.phase = war.phase
        end
    elseif p.mode == 'duel' then
        data.duel = Duels.payload(p)
    end
    return data
end

-- Spieler in einen Modus schicken (Client spawnt danach selbst und meldet "spawned")
function Modes.set(p, mode, arena)
    if p.mode == 'gangwar' and mode ~= 'gangwar' then Gangwar.removePlayer(p) end
    if p.mode == 'duel' and mode ~= 'duel' and p.duelId then Duels.leave(p, 'leave') end
    if mode ~= 'lobby' or p.mode ~= 'lobby' then Garage.cleanup(p) end   -- Hood-Auto bleibt nur an der Hood
    p.mode = mode
    p.arena = mode == 'ffa' and arena or nil
    p.dead = true
    p.spawnAllowedAt = Now()
    p.protectedUntil = 0
    p.lastHit = nil
    p.hp, p.armour = 0, 0
    if mode ~= 'gangwar' then p.warId, p.side = nil, nil end
    AntiCheat.allowMove(p.src, 15)                 -- Moduswechsel = Teleport zum neuen Spawn
    SetPlayerRoutingBucket(p.src, Modes.bucketFor(p))
    Modes.syncState(p)
    TriggerClientEvent('bspvp:mode', p.src, Modes.payload(p))
end

-- Client-Skript neu gestartet: aktuellen Stand nochmal schicken
function Modes.resend(p)
    if p.mode == 'select' or not p.team then
        Teams.openSelect(p)
        return
    end
    p.dead = true
    p.spawnAllowedAt = Now()
    Modes.syncState(p)
    TriggerClientEvent('bspvp:mode', p.src, Modes.payload(p))
    if p.mode == 'gangwar' then Gangwar.sendState(p) end
    TriggerClientEvent('bspvp:zones', p.src, Gangwar.mapView())
end

-- -----------------------------------------------------------------------
--  FFA
-- -----------------------------------------------------------------------
function FFA.join(p, index)
    index = int(index)
    local a = Config.Arenas[index]
    if not a then return Notify(p.src, 'error', 'Diese Arena gibt es nicht.') end
    if p.mode == 'ffa' and p.arena == index then return end
    if p.mode ~= 'lobby' and p.mode ~= 'ffa' then
        return Notify(p.src, 'error', 'Ins FFA kommst du von deiner Hood aus.')
    end
    if (a.max or 0) > 0 and FFA.count(index) >= a.max then
        return Notify(p.src, 'error', ('%s ist voll (%d/%d).'):format(a.name, a.max, a.max))
    end
    Modes.set(p, 'ffa', index)
    Notify(p.src, 'info', ('FFA: %s'):format(a.name))
end

-- Admin: alle Spieler einer Arena zurück zur Hood
function FFA.clear(index)
    local n = 0
    for _, q in pairs(Players) do
        if q.loggedIn and q.mode == 'ffa' and (index == nil or q.arena == index) then
            Modes.set(q, 'lobby')
            n = n + 1
        end
    end
    return n
end

-- -----------------------------------------------------------------------
--  Client -> Server
-- -----------------------------------------------------------------------
RegisterNetEvent('bspvp:joinFFA', function(index)
    local p = Guard(source)
    if not p then return end
    FFA.join(p, index or 1)
end)

RegisterNetEvent('bspvp:toLobby', function()
    local p = Guard(source)
    if not p then return end
    if p.mode == 'ffa' or p.mode == 'gangwar' or p.mode == 'duel' then
        Modes.set(p, 'lobby')
    end
end)
