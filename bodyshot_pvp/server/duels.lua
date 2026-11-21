-- =======================================================================
--  1v1-Duelle (Best of 3)
--  Ablauf: Herausforderung per User-ID -> annehmen -> eigene Welt
--  (Bucket 3000 + Duell-ID) -> Runde: Countdown, Kampf, Ergebnis -> ...
--  Wer zuerst Config.Duels.winRounds Runden hat, gewinnt Einsatz + Bonus.
-- =======================================================================

Duels = { list = {}, invites = {}, nextId = 1, inviteSeq = 0 }

local int = Util.int
local BUCKET = 3000
local SPAWN_MS = 2500      -- Zeit zum Spawnen vor dem Countdown

local function cfg() return Config.Duels or {} end

function Duels.arena(i) return (cfg().arenas or {})[int(i)] end
function Duels.bucket(id) return BUCKET + int(id) end

-- GTA-Heading von a nach b (0 = Norden, gegen den Uhrzeigersinn)
local function headingTo(a, b)
    return (math.deg(math.atan(-(b.x - a.x), b.y - a.y)) + 360.0) % 360.0
end

local function arenaView(i)
    local a = Duels.arena(i)
    if not a then return nil end
    return {
        index = int(i), key = a.key, name = a.name,
        a = { x = a.a.x + 0.0, y = a.a.y + 0.0, z = a.a.z + 0.0, w = headingTo(a.a, a.b) },
        b = { x = a.b.x + 0.0, y = a.b.y + 0.0, z = a.b.z + 0.0, w = headingTo(a.b, a.a) },
        center = { x = (a.a.x + a.b.x) / 2, y = (a.a.y + a.b.y) / 2, z = (a.a.z + a.b.z) / 2 },
        radius = (a.radius or cfg().radius or 45.0) + 0.0,
    }
end
Duels.arenaView = arenaView

-- Daten für Modes.payload (Client spawnt damit)
function Duels.payload(p)
    local duel = p.duelId and Duels.list[p.duelId]
    if not duel then return nil end
    local other = 3 - p.duelSide
    return {
        id = duel.id, side = p.duelSide, arena = arenaView(duel.arena), weapon = duel.weapon,
        opponent = duel.names[other], opponentId = duel.uids[other], stake = duel.stake,
    }
end

function Duels.weaponOf(p)
    local duel = p.duelId and Duels.list[p.duelId]
    return duel and duel.weapon or nil
end

local function playerOf(duel, side)
    local p = PlayerByUserId(duel.uids[side])
    if p and p.duelId == duel.id then return p end
    return nil
end

local function send(duel, event, data)
    for side = 1, 2 do
        local p = playerOf(duel, side)
        if p then
            data.me = side
            TriggerClientEvent(event, p.src, data)
        end
    end
end

local function statePayload(duel, extra)
    local d = {
        id = duel.id, phase = duel.phase, round = duel.round, score = { duel.score[1], duel.score[2] },
        names = { duel.names[1], duel.names[2] }, weapon = (Weapons.get(duel.weapon) or {}).label,
        arena = (Duels.arena(duel.arena) or {}).name, stake = duel.stake, winRounds = cfg().winRounds or 2,
        remaining = duel.phase == 'fight' and math.max(0, math.ceil((duel.roundEndsAt - Now()) / 1000)) or nil,
    }
    for k, v in pairs(extra or {}) do d[k] = v end
    return d
end

-- -----------------------------------------------------------------------
--  Herausfordern & Annehmen
-- -----------------------------------------------------------------------
function Duels.canPlay(p)
    if not p or not p.loggedIn or not p.acc then return false, 'ist nicht eingeloggt.' end
    if p.duelId then return false, 'ist schon in einem Duell.' end
    if p.mode ~= 'lobby' and p.mode ~= 'ffa' then return false, 'kann gerade nicht (nur von der Hood oder aus dem FFA).' end
    return true
end

local function strongestWeapon(acc)
    for i = #Weapons.list, 1, -1 do
        if Accounts.owns(acc, Weapons.list[i].name) then return Weapons.list[i] end
    end
    return nil
end

function Duels.challenge(p, targetUid, arenaIndex, weaponName, stake)
    if not cfg().enabled then return Notify(p.src, 'error', 'Duelle sind ausgeschaltet.') end
    local t = Now()
    local wait = (cfg().cooldown or 15) * 1000 - (t - (p.lastDuelChallenge or -1e9))
    if wait > 0 then return Notify(p.src, 'error', ('Warte noch %d Sekunden.'):format(math.ceil(wait / 1000))) end

    local target = PlayerByUserId(targetUid)
    if not target then return Notify(p.src, 'error', 'Dieser Spieler ist nicht online.') end
    if target == p then return Notify(p.src, 'error', 'Du kannst dich nicht selbst herausfordern.') end
    local ok, why = Duels.canPlay(p)
    if not ok then return Notify(p.src, 'error', 'Du ' .. why:gsub('^ist', 'bist'):gsub('^kann', 'kannst')) end
    ok, why = Duels.canPlay(target)
    if not ok then return Notify(p.src, 'error', target.acc.name .. ' ' .. why) end

    local arenas = cfg().arenas or {}
    if #arenas == 0 then return Notify(p.src, 'error', 'Es gibt keine Duell-Arenen.') end
    arenaIndex = int(arenaIndex)
    if not arenas[arenaIndex] then arenaIndex = math.random(#arenas) end

    local w = weaponName and Weapons.get(weaponName) or strongestWeapon(p.acc)
    if not w or not Accounts.owns(p.acc, w.name) then return Notify(p.src, 'error', 'Diese Waffe hast du nicht.') end

    stake = math.max(0, math.min(int(stake), int(cfg().maxStake or 0)))
    if p.acc.money < stake then return Notify(p.src, 'error', ('Dir fehlen $%s für den Einsatz.'):format(Util.formatMoney(stake - p.acc.money))) end

    local existing = Duels.invites[target.acc.id]
    if existing and existing.expires > t then
        return Notify(p.src, 'error', ('%s hat schon eine offene Herausforderung.'):format(target.acc.name))
    end

    Duels.inviteSeq = Duels.inviteSeq + 1
    local seconds = cfg().inviteSeconds or 30
    local inv = { seq = Duels.inviteSeq, from = p.acc.id, arena = arenaIndex, weapon = w.name, stake = stake, expires = t + seconds * 1000 }
    Duels.invites[target.acc.id] = inv
    p.lastDuelChallenge = t

    TriggerClientEvent('bspvp:duelInvite', target.src, {
        from = p.acc.name, fromId = p.acc.id, arena = arenas[arenaIndex].name, weapon = w.label, stake = stake, seconds = seconds,
    })
    Notify(p.src, 'info', ('Herausforderung an %s geschickt: %s, %s%s.'):format(target.acc.name, arenas[arenaIndex].name, w.label,
        stake > 0 and (', Einsatz $' .. Util.formatMoney(stake)) or ''))

    local targetUid2, seq = target.acc.id, inv.seq
    SetTimeout(seconds * 1000 + 100, function()
        local cur = Duels.invites[targetUid2]
        if cur and cur.seq == seq then
            Duels.invites[targetUid2] = nil
            local c, tp = PlayerByUserId(cur.from), PlayerByUserId(targetUid2)
            if tp then TriggerClientEvent('bspvp:duelInvite', tp.src, false) end
            if c then Notify(c.src, 'info', ('%s hat nicht reagiert.'):format(tp and tp.acc.name or 'Der Spieler')) end
        end
    end)
end

function Duels.respond(p, accept)
    local inv = Duels.invites[p.acc.id]
    if not inv or inv.expires < Now() then
        Duels.invites[p.acc.id] = nil
        return Notify(p.src, 'error', 'Du hast keine offene Herausforderung.')
    end
    Duels.invites[p.acc.id] = nil
    TriggerClientEvent('bspvp:duelInvite', p.src, false)
    local c = PlayerByUserId(inv.from)
    if not accept then
        if c then Notify(c.src, 'info', ('%s hat dein Duell abgelehnt.'):format(p.acc.name)) end
        return Notify(p.src, 'info', 'Duell abgelehnt.')
    end
    if not c then return Notify(p.src, 'error', 'Der Herausforderer ist nicht mehr online.') end
    local ok, why = Duels.canPlay(c)
    if not ok then return Notify(p.src, 'error', c.acc.name .. ' ' .. why) end
    ok, why = Duels.canPlay(p)
    if not ok then return Notify(p.src, 'error', 'Du ' .. why:gsub('^ist', 'bist'):gsub('^kann', 'kannst')) end
    if c.acc.money < inv.stake then
        Notify(c.src, 'error', 'Du hast nicht mehr genug Geld für den Einsatz.')
        return Notify(p.src, 'error', ('%s hat nicht mehr genug Geld für den Einsatz.'):format(c.acc.name))
    end
    if p.acc.money < inv.stake then
        return Notify(p.src, 'error', ('Dir fehlen $%s für den Einsatz.'):format(Util.formatMoney(inv.stake - p.acc.money)))
    end
    Duels.start(c, p, inv)
end

-- -----------------------------------------------------------------------
--  Ablauf
-- -----------------------------------------------------------------------
function Duels.start(a, b, inv)
    local id = Duels.nextId
    Duels.nextId = id + 1
    local duel = {
        id = id, arena = inv.arena, weapon = inv.weapon, stake = inv.stake,
        uids = { a.acc.id, b.acc.id }, names = { a.acc.name, b.acc.name },
        score = { 0, 0 }, round = 0, phase = 'starting', started = os.time(),
    }
    Duels.list[id] = duel
    SetRoutingBucketPopulationEnabled(Duels.bucket(id), false)
    for side, p in ipairs({ a, b }) do
        if duel.stake > 0 then
            Accounts.addMoney(p.acc, -duel.stake)
            Accounts.save(p.acc)
            Accounts.push(p)
        end
        p.duelId, p.duelSide = id, side
        Modes.set(p, 'duel')
    end
    Duels.startRound(duel)
end

function Duels.startRound(duel)
    duel.round = duel.round + 1
    duel.phase = 'countdown'
    local cd = cfg().countdown or 3
    duel.fightAt = Now() + SPAWN_MS + cd * 1000
    duel.roundEndsAt = duel.fightAt + (cfg().roundSeconds or 90) * 1000
    send(duel, 'bspvp:duelState', statePayload(duel, { countdown = cd, startsIn = (SPAWN_MS / 1000) + cd, roundSeconds = cfg().roundSeconds or 90 }))
end

-- Beide neu an ihre Startpunkte (neue Runde)
function Duels.respawnBoth(duel)
    for side = 1, 2 do
        local p = playerOf(duel, side)
        if p then
            p.dead = true
            p.hp, p.armour = 0, 0
            p.lastHit = nil
            p.spawnAllowedAt = Now()
            TriggerClientEvent('bspvp:mode', p.src, Modes.payload(p))
        end
    end
end

function Duels.roundWon(duel, side, how)
    if duel.phase ~= 'fight' then return end
    duel.phase = 'roundEnd'
    if side then duel.score[side] = duel.score[side] + 1 end
    local winRounds = cfg().winRounds or 2
    if side and duel.score[side] >= winRounds then
        duel.finishing = side
    elseif duel.round >= winRounds * 2 + 1 then               -- zu viele Unentschieden
        duel.finishing = duel.score[1] > duel.score[2] and 1 or (duel.score[2] > duel.score[1] and 2 or 0)
    end
    duel.nextAt = Now() + 3000
    send(duel, 'bspvp:duelState', statePayload(duel, {
        winner = side, winnerName = side and duel.names[side] or nil, how = how, last = duel.finishing ~= nil,
    }))
end

-- Tod im Duell (aus Combat.handleDeath)
function Duels.onDeath(victim, killer)
    local duel = victim.duelId and Duels.list[victim.duelId]
    if not duel then return end
    if duel.phase == 'fight' then
        Duels.roundWon(duel, 3 - victim.duelSide, killer and 'kill' or 'self')
    elseif duel.phase == 'countdown' or duel.phase == 'starting' then
        -- vor dem Start gestorben (z. B. runtergefallen): einfach neu hinstellen
        SetTimeout(1500, function()
            if victim.duelId == duel.id and victim.dead then
                victim.spawnAllowedAt = Now()
                TriggerClientEvent('bspvp:mode', victim.src, Modes.payload(victim))
            end
        end)
    end
end

-- Zeit abgelaufen: mehr Leben + Weste gewinnt, sonst Unentschieden
local function timeout(duel)
    local a, b = playerOf(duel, 1), playerOf(duel, 2)
    local va = a and not a.dead and (a.hp + a.armour) or 0
    local vb = b and not b.dead and (b.hp + b.armour) or 0
    if va > vb then Duels.roundWon(duel, 1, 'time')
    elseif vb > va then Duels.roundWon(duel, 2, 'time')
    else Duels.roundWon(duel, nil, 'time') end
end

function Duels.finish(duel, winner, reason)
    if duel.phase == 'ended' then return end
    duel.phase = 'ended'
    Duels.list[duel.id] = nil
    local accs = { Accounts.get(duel.uids[1]), Accounts.get(duel.uids[2]) }
    local pot = duel.stake * 2
    local reward = cfg().reward or {}

    for side = 1, 2 do
        local acc = accs[side]
        if acc then
            Missions.track(acc, 'duelPlayed', 1)
            if winner == 0 then
                Accounts.addMoney(acc, duel.stake)                    -- Unentschieden: Einsatz zurück
            elseif side == winner then
                acc.stats.duelWins = int(acc.stats.duelWins) + 1
                Accounts.addMoney(acc, pot + (reward.money or 0))
                local p = PlayerByUserId(acc.id)
                if p then Accounts.addXp(p, reward.xp or 0) else acc.xp = acc.xp + int(reward.xp) end
                Missions.track(acc, 'duelWin', 1)
            else
                acc.stats.duelLosses = int(acc.stats.duelLosses) + 1
            end
            Accounts.save(acc)
        end
    end

    local scoreText
    if winner == 1 or winner == 2 then
        local l = 3 - winner
        scoreText = ('%d:%d'):format(duel.score[winner], duel.score[l])
        DB.log('duel', { winner_id = duel.uids[winner], loser_id = duel.uids[l], score = scoreText, stake = duel.stake,
            weapon = duel.weapon, arena = (Duels.arena(duel.arena) or {}).key or '', reason = reason or 'win' })
        local how = reason == 'forfeit' and ' (aufgegeben)' or ''
        Chat(-1, ('^5Duell:^7 ^3%s^7 besiegt ^3%s^7 %s%s%s'):format(duel.names[winner], duel.names[l], scoreText, how,
            duel.stake > 0 and (' und kassiert ^2$' .. Util.formatMoney(pot) .. '^7') or ''))
        if duel.stake >= (cfg().announceStake or math.huge) then
            Announce(-1, ('%s gewinnt das Duell gegen %s (%s) und kassiert $%s'):format(duel.names[winner], duel.names[l], scoreText, Util.formatMoney(pot)))
        end
    else
        scoreText = ('%d:%d'):format(duel.score[1], duel.score[2])
    end

    for side = 1, 2 do
        local p = playerOf(duel, side)
        if p then
            p.duelId, p.duelSide = nil, nil
            TriggerClientEvent('bspvp:duelEnd', p.src, {
                won = side == winner, draw = winner == 0, reason = reason,
                score = { duel.score[side], duel.score[3 - side] }, opponent = duel.names[3 - side],
                pot = (side == winner) and (pot + (reward.money or 0)) or (winner == 0 and duel.stake or 0),
                xp = (side == winner) and (reward.xp or 0) or 0, stake = duel.stake,
            })
            if p.team then Modes.set(p, 'lobby') else Teams.openSelect(p) end
            Accounts.push(p)
        end
    end
end

-- Duell verlassen (Disconnect, /hood, Teamwechsel, Admin): der andere gewinnt
function Duels.leave(p, reason)
    local duel = p.duelId and Duels.list[p.duelId]
    local side = p.duelSide
    p.duelId, p.duelSide = nil, nil
    if not duel then return end
    local other = 3 - side
    if duel.phase ~= 'ended' then
        local o = playerOf(duel, other)
        if o then Notify(o.src, 'info', ('%s hat das Duell verlassen – du gewinnst.'):format(duel.names[side])) end
        duel.score[other] = math.max(duel.score[other], cfg().winRounds or 2)
        Duels.finish(duel, other, 'forfeit')
    end
end

-- Offene Herausforderungen von/an diesen Spieler löschen
function Duels.dropInvites(p)
    if not p.acc then return end
    Duels.invites[p.acc.id] = nil
    for uid, inv in pairs(Duels.invites) do
        if inv.from == p.acc.id then
            Duels.invites[uid] = nil
            local tp = PlayerByUserId(uid)
            if tp then TriggerClientEvent('bspvp:duelInvite', tp.src, false) end
        end
    end
end

-- Menü
function Duels.view(p)
    local arenas = {}
    for i in ipairs(cfg().arenas or {}) do arenas[#arenas + 1] = arenaView(i) end
    local inv = p and Duels.invites[p.acc.id]
    local incoming
    if inv and inv.expires > Now() then
        local from = Accounts.get(inv.from)
        local w = Weapons.get(inv.weapon)
        incoming = { from = from and from.name or '?', fromId = inv.from, arena = (Duels.arena(inv.arena) or {}).name,
            weapon = w and w.label or inv.weapon, stake = inv.stake, seconds = math.max(0, math.ceil((inv.expires - Now()) / 1000)) }
    end
    local running = {}
    for _, d in pairs(Duels.list) do
        running[#running + 1] = { names = d.names, score = d.score, round = d.round, arena = (Duels.arena(d.arena) or {}).name, stake = d.stake }
    end
    local s = p and p.acc.stats or {}
    return {
        enabled = cfg().enabled == true, arenas = arenas, incoming = incoming, running = running,
        maxStake = cfg().maxStake or 0, winRounds = cfg().winRounds or 2, roundSeconds = cfg().roundSeconds or 90,
        wins = int(s.duelWins), losses = int(s.duelLosses),
    }
end

-- Takt: Countdown -> Kampf -> Zeit -> nächste Runde
CreateThread(function()
    while true do
        Wait(250)
        local t = Now()
        for _, duel in pairs(Duels.list) do
            if duel.phase == 'countdown' and t >= duel.fightAt then
                duel.phase = 'fight'
                duel.roundEndsAt = t + (cfg().roundSeconds or 90) * 1000
                send(duel, 'bspvp:duelState', statePayload(duel))
            elseif duel.phase == 'fight' and t >= duel.roundEndsAt then
                timeout(duel)
            elseif duel.phase == 'roundEnd' and t >= (duel.nextAt or 0) then
                if duel.finishing ~= nil then
                    Duels.finish(duel, duel.finishing, 'win')
                else
                    Duels.respawnBoth(duel)
                    Duels.startRound(duel)
                end
            end
        end
    end
end)

-- -----------------------------------------------------------------------
--  Client -> Server
-- -----------------------------------------------------------------------
RegisterNetEvent('bspvp:duelChallenge', function(targetUid, arena, weapon, stake)
    local p = Guard(source)
    if not p then return end
    Duels.challenge(p, int(targetUid), arena, weapon and tostring(weapon) or nil, stake)
    Progress.sendMenu(p)
end)

RegisterNetEvent('bspvp:duelRespond', function(accept)
    local p = Guard(source)
    if not p then return end
    Duels.respond(p, accept == true)
end)

RegisterNetEvent('bspvp:duelLeave', function()
    local p = Guard(source)
    if p and p.duelId then Duels.leave(p, 'leave') end
end)
