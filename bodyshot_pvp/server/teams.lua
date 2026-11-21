-- =======================================================================
--  Teams: GTA-Gangs + Private Teams
-- =======================================================================

Teams = { private = {} }    -- [teamId] = { id, name, tag, color, leader, members = { userId, ... } }

local int = Util.int

-- Hex-Farbe -> passende Blip-Farbe für private Teams
local BLIP_FOR_COLOR = {
    ['#ff3b3b'] = 1, ['#ff8c1a'] = 17, ['#ffd400'] = 5, ['#33cc66'] = 2, ['#1ec8c8'] = 3,
    ['#2f80ff'] = 38, ['#8a5cff'] = 27, ['#ff4fa3'] = 8, ['#f2f2f2'] = 0, ['#8c8c8c'] = 40,
}

function Teams.key(ref)
    if not ref then return nil end
    return ref.kind .. ':' .. tostring(ref.kind == 'private' and int(ref.id) or ref.id)
end

function Teams.same(a, b)
    return a ~= nil and b ~= nil and Teams.key(a) == Teams.key(b)
end

function Teams.copy(ref)
    if not ref then return nil end
    return { kind = ref.kind, id = ref.kind == 'private' and int(ref.id) or ref.id }
end

function Teams.info(ref)
    if not ref then return nil end
    if ref.kind == 'gang' then
        local g = Util.gang(ref.id)
        if not g then return nil end
        return {
            kind = 'gang', id = g.id, key = 'gang:' .. g.id,
            name = g.name, tag = g.tag, color = g.color, blip = g.blip,
            outfit = g.outfit or 'silver',
        }
    elseif ref.kind == 'private' then
        local t = Teams.private[int(ref.id)]
        if not t then return nil end
        return {
            kind = 'private', id = t.id, key = 'private:' .. t.id,
            name = t.name, tag = t.tag, color = t.color, blip = BLIP_FOR_COLOR[t.color] or 0,
            outfit = Util.privateOutfit(t.color), leader = t.leader,
        }
    end
    return nil
end

function Teams.online(ref)
    local key, n = Teams.key(ref), 0
    for _, p in pairs(Players) do
        if p.loggedIn and Teams.key(p.team) == key then n = n + 1 end
    end
    return n
end

-- Team voll? (der Spieler selbst zählt nicht mit)
function Teams.full(ref, p)
    local max = Config.TeamMax or 0
    if max <= 0 or (ref and ref.kind == 'private') then return false end
    local n = Teams.online(ref)
    if p and Teams.same(p.team, ref) then n = n - 1 end
    return n >= max
end

local function saveTeam(t) DB.set('team:' .. t.id, t) end

function Teams.loadAll()
    for _, key in ipairs(DB.keys('team:')) do
        local t = DB.get(key)
        if type(t) == 'table' and t.id ~= nil then
            t.id = int(t.id)
            t.leader = int(t.leader)
            local members = {}
            for _, uid in ipairs(t.members or {}) do members[#members + 1] = int(uid) end
            t.members = members
            Teams.private[t.id] = t
        end
    end
end

local function isMember(t, uid)
    for _, m in ipairs(t.members) do
        if m == uid then return true end
    end
    return false
end

local function removeMember(t, uid)
    for i = #t.members, 1, -1 do
        if t.members[i] == uid then table.remove(t.members, i) end
    end
end

-- Spieler verliert sein (aktives) privates Team -> neu wählen lassen
local function dropFromTeam(uid, teamId, reason)
    local acc = Accounts.get(uid)
    if acc and acc.privateTeam == teamId then
        acc.privateTeam = nil
        if acc.lastTeam and acc.lastTeam.kind == 'private' and int(acc.lastTeam.id) == teamId then acc.lastTeam = nil end
        Accounts.save(acc)
    end
    local p = PlayerByUserId(uid)
    if p then
        if reason then Notify(p.src, 'info', reason) end
        if p.team and p.team.kind == 'private' and int(p.team.id) == teamId then
            if p.mode == 'gangwar' then Gangwar.removePlayer(p) end
            p.team = nil
            Teams.openSelect(p)
        end
    end
end

-- Gültige Team-Referenz für diesen Spieler (oder nil)
function Teams.resolve(p, kind, id)
    if kind == 'gang' and Util.gang(id) then
        return { kind = 'gang', id = id }
    elseif kind == 'private' and p.acc.privateTeam and int(id) == p.acc.privateTeam and Teams.private[p.acc.privateTeam] then
        return { kind = 'private', id = p.acc.privateTeam }
    end
    return nil
end

-- Team beitreten -> an die Hood
function Teams.join(p, ref)
    local info = Teams.info(ref)
    if not info then return false end
    p.team = Teams.copy(ref)
    p.acc.lastTeam = Teams.copy(ref)
    Accounts.save(p.acc)
    Modes.set(p, 'lobby')
    TriggerClientEvent('bspvp:joined', p.src, { name = info.name, tag = info.tag, color = info.color, kind = info.kind, id = info.id })
    return true
end

-- -----------------------------------------------------------------------
--  Team-Auswahl (F1)
-- -----------------------------------------------------------------------
function Teams.selectPayload(p)
    local gangs = {}
    for _, g in ipairs(Config.Gangs) do
        local ref = { kind = 'gang', id = g.id }
        gangs[#gangs + 1] = {
            id = g.id, name = g.name, tag = g.tag, color = g.color,
            online = Teams.online(ref),
            max = Config.TeamMax or 0,
            zones = Gangwar.ownedCount(Teams.key(ref)),
            hood = Hoods.get(ref).name,
            full = Teams.full(ref, p),
        }
    end
    local private = {}
    local mine = p.acc.privateTeam
    for _, t in pairs(Teams.private) do
        local ref = { kind = 'private', id = t.id }
        private[#private + 1] = {
            id = t.id, name = t.name, tag = t.tag, color = t.color,
            members = #t.members, online = Teams.online(ref), max = Config.PrivateTeams.maxMembers,
            zones = Gangwar.ownedCount(Teams.key(ref)),
            hood = Hoods.get(ref).name,
            member = t.id == mine,
            leader = t.leader == p.acc.id,
        }
    end
    table.sort(private, function(a, b)
        if a.member ~= b.member then return a.member end
        if a.online ~= b.online then return a.online > b.online end
        if a.members ~= b.members then return a.members > b.members end
        return a.id < b.id
    end)
    for i = #private, 61, -1 do private[i] = nil end      -- höchstens 60 anzeigen
    local colors = {}
    for _, c in ipairs(Config.PrivateTeams.colors or {}) do colors[#colors + 1] = c.hex end
    return {
        gangs = gangs,
        private = private,
        current = Teams.key(p.team or p.acc.lastTeam),
        canCreate = Config.PrivateTeams.enabled and not p.acc.privateTeam,
        createPrice = Config.PrivateTeams.price,
        colors = colors,
        maxMembers = Config.PrivateTeams.maxMembers,
        money = p.acc.money,
    }
end

-- Team gründen direkt aus der Team-Auswahl (F1)
RegisterNetEvent('bspvp:createTeam', function(name, tag, color)
    local p = Guard(source)
    if not p then return end
    Teams.create(p, tostring(name or ''), tostring(tag or ''), tostring(color or ''))
    if p.mode == 'select' then
        TriggerClientEvent('bspvp:teamSelect', p.src, (function()
            local payload = Teams.selectPayload(p)
            payload.closable = false
            return payload
        end)())
    end
end)

-- Auswahl öffnen. In der Lobby MIT Team bleibt sie schließbar (F1);
-- ohne Team (Team verloren, aufgelöst, gekickt) muss neu gewählt werden.
function Teams.openSelect(p)
    if p.mode == 'gangwar' then Gangwar.removePlayer(p) end
    if p.mode ~= 'lobby' or not p.team then
        if p.mode == 'lobby' then Garage.cleanup(p) end
        if p.mode == 'duel' and Duels then Duels.leave(p, 'team') end
        p.mode = 'select'
        p.dead = true
        p.arena = nil
        p.hp, p.armour = 0, 0
        SetPlayerRoutingBucket(p.src, 5000 + p.src)
        if Modes and Modes.syncState then Modes.syncState(p) end
    end
    local payload = Teams.selectPayload(p)
    payload.closable = p.mode == 'lobby'
    TriggerClientEvent('bspvp:teamSelect', p.src, payload)
end

RegisterNetEvent('bspvp:teams', function()
    local p = Guard(source)
    if not p then return end
    if p.mode == 'ffa' or p.mode == 'gangwar' then
        return Notify(p.src, 'error', 'Teams wechselst du an deiner Hood.')
    end
    TriggerClientEvent('bspvp:teamSelect', p.src, Teams.selectPayload(p))
end)

RegisterNetEvent('bspvp:selectTeam', function(kind, id)
    local p = Players[source]
    if not p or not p.loggedIn then return end
    if p.mode ~= 'select' and p.mode ~= 'lobby' then
        Notify(p.src, 'error', 'Teams wechselst du an deiner Hood.')
        return
    end
    local ref = Teams.resolve(p, kind, id)
    if not ref then
        Notify(p.src, 'error', 'Dieses Team gibt es nicht.')
        TriggerClientEvent('bspvp:teamSelect', p.src, Teams.selectPayload(p))
        return
    end
    if Teams.full(ref, p) then
        Notify(p.src, 'error', 'Dieses Team ist gerade voll.')
        TriggerClientEvent('bspvp:teamSelect', p.src, Teams.selectPayload(p))
        return
    end
    if Teams.same(p.team, ref) and p.mode == 'lobby' then
        TriggerClientEvent('bspvp:closeSelect', p.src)
        return
    end
    Teams.join(p, ref)
end)

-- -----------------------------------------------------------------------
--  Private Teams
-- -----------------------------------------------------------------------
local function nameTaken(name, tag)
    local lname, ltag = string.lower(name), string.lower(tag)
    for _, g in ipairs(Config.Gangs) do
        if string.lower(g.name) == lname or string.lower(g.tag) == ltag then return true end
    end
    for _, t in pairs(Teams.private) do
        if string.lower(t.name) == lname or string.lower(t.tag) == ltag then return true end
    end
    return false
end

function Teams.create(p, name, tag, color)
    if not Config.PrivateTeams.enabled then return Notify(p.src, 'error', 'Private Teams sind deaktiviert.') end
    if p.acc.privateTeam then return Notify(p.src, 'error', 'Du bist schon in einem privaten Team.') end
    if p.mode ~= 'lobby' and p.mode ~= 'select' then return Notify(p.src, 'error', 'Teams gründest du an deiner Hood oder in der Team-Auswahl (F1).') end
    name = Util.trim(name)
    tag = string.upper(Util.trim(tag))
    if #name < 3 or #name > 20 or not name:match('^[%w _%-]+$') then
        return Notify(p.src, 'error', 'Teamname: 3–20 Zeichen (Buchstaben, Zahlen, Leerzeichen, - und _).')
    end
    if #tag < 2 or #tag > 4 or not tag:match('^[%w]+$') then
        return Notify(p.src, 'error', 'Kürzel: 2–4 Buchstaben oder Zahlen.')
    end
    if not Util.privateColorAllowed(color) then return Notify(p.src, 'error', 'Bitte eine Farbe auswählen.') end
    if nameTaken(name, tag) then return Notify(p.src, 'error', 'Name oder Kürzel ist schon vergeben.') end
    local price = Config.PrivateTeams.price
    if p.acc.money < price then
        return Notify(p.src, 'error', ('Du brauchst $%s für ein eigenes Team.'):format(Util.formatMoney(price)))
    end

    local id = DB.nextId('team') + 1     -- Team-IDs ab 1
    local t = { id = id, name = name, tag = tag, color = color, leader = p.acc.id, members = { p.acc.id }, created = os.time() }
    Teams.private[id] = t
    saveTeam(t)

    Accounts.addMoney(p.acc, -price)
    p.acc.privateTeam = id
    Accounts.push(p)
    Teams.join(p, { kind = 'private', id = id })
    Notify(p.src, 'success', ('Team [%s] %s gegründet!'):format(tag, name))
    Chat(-1, ('^7Neues Team: ^5[%s] %s^7 von %s'):format(tag, name, p.acc.name))
    Logs.add('team', ('%s gründet **[%s] %s**'):format(Logs.who(p), tag, name))
end

function Teams.invite(p, targetUid)
    local t = p.acc.privateTeam and Teams.private[p.acc.privateTeam]
    if not t then return Notify(p.src, 'error', 'Du hast kein privates Team.') end
    if t.leader ~= p.acc.id then return Notify(p.src, 'error', 'Nur der Leader kann einladen.') end
    if #t.members >= Config.PrivateTeams.maxMembers then return Notify(p.src, 'error', 'Dein Team ist voll.') end
    local target = PlayerByUserId(targetUid)
    if not target or not target.loggedIn then return Notify(p.src, 'error', ('User #%d ist nicht online.'):format(int(targetUid))) end
    if target == p then return Notify(p.src, 'error', 'Du kannst dich nicht selbst einladen.') end
    if target.acc.privateTeam then return Notify(p.src, 'error', ('%s ist schon in einem privaten Team.'):format(target.acc.name)) end
    target.invite = { teamId = t.id, from = p.acc.name, expires = os.time() + 120 }
    TriggerClientEvent('bspvp:teamInvite', target.src, { team = t.name, tag = t.tag, color = t.color, from = p.acc.name })
    Notify(p.src, 'success', ('Einladung an %s #%d geschickt.'):format(target.acc.name, target.acc.id))
end

function Teams.acceptInvite(p)
    local inv = p.invite
    p.invite = nil
    if not inv or os.time() > inv.expires then return Notify(p.src, 'error', 'Keine gültige Einladung.') end
    local t = Teams.private[inv.teamId]
    if not t then return Notify(p.src, 'error', 'Das Team gibt es nicht mehr.') end
    if p.acc.privateTeam then return Notify(p.src, 'error', 'Verlasse zuerst dein aktuelles Team.') end
    if #t.members >= Config.PrivateTeams.maxMembers then return Notify(p.src, 'error', 'Das Team ist voll.') end
    if not isMember(t, p.acc.id) then t.members[#t.members + 1] = p.acc.id end
    saveTeam(t)
    p.acc.privateTeam = t.id
    Accounts.save(p.acc)
    Notify(p.src, 'success', ('Du bist jetzt in [%s] %s. Mit F1 unter "Private" wechselst du hinein.'):format(t.tag, t.name))
    for _, uid in ipairs(t.members) do
        local q = PlayerByUserId(uid)
        if q and q ~= p then Notify(q.src, 'info', ('%s ist deinem Team beigetreten.'):format(p.acc.name)) end
    end
end

function Teams.declineInvite(p)
    p.invite = nil
end

function Teams.kick(p, uid)
    uid = int(uid)
    local t = p.acc.privateTeam and Teams.private[p.acc.privateTeam]
    if not t or t.leader ~= p.acc.id then return Notify(p.src, 'error', 'Nur der Leader kann Mitglieder entfernen.') end
    if uid == p.acc.id then return Notify(p.src, 'error', 'Du kannst dich nicht selbst entfernen.') end
    if not isMember(t, uid) then return Notify(p.src, 'error', 'Dieser Spieler ist nicht im Team.') end
    removeMember(t, uid)
    saveTeam(t)
    dropFromTeam(uid, t.id, ('Du wurdest aus [%s] %s entfernt.'):format(t.tag, t.name))
    Notify(p.src, 'success', 'Mitglied entfernt.')
end

function Teams.leave(p)
    local t = p.acc.privateTeam and Teams.private[p.acc.privateTeam]
    if not t then return Notify(p.src, 'error', 'Du bist in keinem privaten Team.') end
    if t.leader == p.acc.id then return Notify(p.src, 'error', 'Als Leader kannst du das Team nur auflösen.') end
    removeMember(t, p.acc.id)
    saveTeam(t)
    dropFromTeam(p.acc.id, t.id, ('Du hast [%s] %s verlassen.'):format(t.tag, t.name))
end

function Teams.disband(p, byAdmin)
    local t
    if byAdmin then
        t = Teams.private[int(byAdmin)]
        if not t then return false end
    else
        t = p.acc.privateTeam and Teams.private[p.acc.privateTeam]
        if not t or t.leader ~= p.acc.id then return Notify(p.src, 'error', 'Nur der Leader kann das Team auflösen.') end
    end
    if Gangwar.teamInWar(Teams.key({ kind = 'private', id = t.id })) then
        if p then Notify(p.src, 'error', 'Während eines Gangwars geht das nicht.') end
        return false
    end
    Teams.private[t.id] = nil
    DB.set('team:' .. t.id, nil)
    Logs.add('team', ('[%s] %s wurde aufgelöst (%s)'):format(t.tag, t.name, byAdmin and 'Admin' or Logs.who(p)))
    Gangwar.clearOwner(Teams.key({ kind = 'private', id = t.id }))
    for _, uid in ipairs(t.members) do
        dropFromTeam(uid, t.id, ('Das Team [%s] %s wurde aufgelöst.'):format(t.tag, t.name))
    end
    return true
end

-- Daten fürs Menü
function Teams.menuView(p)
    local view = { current = Teams.info(p.team), invite = nil, private = nil }
    if p.invite and os.time() <= p.invite.expires then
        local t = Teams.private[p.invite.teamId]
        if t then view.invite = { team = t.name, tag = t.tag, color = t.color, from = p.invite.from } end
    end
    local t = p.acc.privateTeam and Teams.private[p.acc.privateTeam]
    if t then
        local members = {}
        for _, uid in ipairs(t.members) do
            local acc = Accounts.get(uid)
            local online = PlayerByUserId(uid)
            members[#members + 1] = {
                id = uid,
                name = acc and acc.name or ('#' .. uid),
                leader = uid == t.leader,
                online = online ~= nil,
                level = acc and Accounts.level(acc) or 1,
            }
        end
        table.sort(members, function(a, b)
            if a.leader ~= b.leader then return a.leader end
            if a.online ~= b.online then return a.online end
            return a.id < b.id
        end)
        view.private = {
            id = t.id, name = t.name, tag = t.tag, color = t.color,
            leader = t.leader == p.acc.id, members = members,
            max = Config.PrivateTeams.maxMembers,
            zones = Gangwar.ownedCount(Teams.key({ kind = 'private', id = t.id })),
            hood = Hoods.get({ kind = 'private', id = t.id }).name,
        }
    end
    local colors = {}
    for _, c in ipairs(Config.PrivateTeams.colors or {}) do colors[#colors + 1] = c.hex end
    view.createPrice = Config.PrivateTeams.price
    view.maxMembers = Config.PrivateTeams.maxMembers
    view.colors = colors
    view.enabled = Config.PrivateTeams.enabled
    return view
end
