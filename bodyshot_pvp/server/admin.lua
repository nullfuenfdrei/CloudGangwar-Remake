-- =======================================================================
--  Admin-Menü (F6) + Banns
--  Wer was darf, steht in Config.Staff (Ränge Support … Owner, server/staff.lua).
--  Jede Aktion wird hier auf dem Server geprüft – der Client kann nichts erzwingen.
-- =======================================================================

Admin = {}

local int = Util.int

local function adminName(src)
    if src == 0 then return Admin.actor or 'Konsole' end
    local p = Players[src]
    return p and p.acc and p.acc.name or GetPlayerName(src) or ('#' .. src)
end

local function log(src, text)
    print(('^3[Admin]^7 %s: %s'):format(adminName(src), text))
end

-- Zugang zum Admin-Menü: irgendein Team-Rang (ab Support)
function IsAdmin(src)
    return src == 0 or Staff.rank(src) ~= nil
end

-- -----------------------------------------------------------------------
--  Banns
-- -----------------------------------------------------------------------
function Admin.banText(ban)
    local untilText = (ban['until'] or 0) == 0 and 'für immer' or ('bis ' .. os.date('%d.%m.%Y %H:%M', ban['until']))
    return ('Du bist gebannt (%s). Grund: %s'):format(untilText, ban.reason ~= '' and ban.reason or 'kein Grund angegeben')
end

-- Aktiver Bann für diese Lizenz (abgelaufene werden gelöscht)
function Admin.activeBan(license)
    local ban = DB.getBan(license)
    if not ban then return nil end
    if (ban['until'] or 0) ~= 0 and ban['until'] <= os.time() then
        DB.setBan(license, nil)
        return nil
    end
    return ban
end

function Admin.ban(src, acc, hours, reason, byName)
    if not acc or not acc.license then return false end
    hours = tonumber(hours) or 0
    local ban = {
        name = acc.name, uid = acc.id, reason = Util.trim(reason):sub(1, 120),
        by = byName or adminName(src), at = os.time(),
        ['until'] = hours > 0 and (os.time() + math.floor(hours * 3600)) or 0,
    }
    DB.setBan(acc.license, ban)
    local p = PlayerByUserId(acc.id)
    local who = p and Logs.who(p) or ('%s #%d'):format(acc.name, acc.id)
    if p then DropPlayer(p.src, Admin.banText(ban)) end
    log(src, ('bannt %s #%d (%s, %s)'):format(acc.name, acc.id, hours > 0 and (hours .. ' h') or 'für immer', ban.reason))
    Logs.add('ban', ('%s wurde gebannt'):format(who), {
        { 'Von', ban.by, true }, { 'Dauer', hours > 0 and (hours .. ' Stunden') or 'für immer', true }, { 'Grund', ban.reason ~= '' and ban.reason or '–' },
    })
    return true
end

-- -----------------------------------------------------------------------
--  Daten fürs Menü
-- -----------------------------------------------------------------------
function Admin.payload(src)
    local players = {}
    for _, q in pairs(Players) do
        if q.loggedIn and q.acc then
            local info = Teams.info(q.team)
            local place = Progress.placeName(q)
            local rank = Staff.info(Staff.rank(q.src))
            players[#players + 1] = {
                rank = rank, savedRank = q.acc.staffRank,
                sid = q.src, id = q.acc.id, name = q.acc.name,
                team = info and info.name or nil, tag = info and info.tag or nil, color = info and info.color or nil,
                place = place, level = Accounts.level(q.acc), money = q.acc.money,
                kills = q.acc.stats.kills, deaths = q.acc.stats.deaths, premium = q.acc.premium, premiumText = Accounts.premiumText(q.acc),
                muted = math.ceil(ChatSys.mutedFor(q.acc) / 60), dead = q.dead,
                bounty = Bounty.amount(q.acc.id), duel = q.duelId ~= nil,
                ping = GetPlayerPing and GetPlayerPing(q.src) or 0,
            }
        end
    end
    table.sort(players, function(a, b) return a.id < b.id end)

    local teams = { { key = '', name = 'Frei', tag = '–' } }
    for _, g in ipairs(Config.Gangs) do teams[#teams + 1] = { key = 'gang:' .. g.id, name = g.name, tag = g.tag, color = g.color } end
    for _, t in pairs(Teams.private) do teams[#teams + 1] = { key = 'private:' .. t.id, name = t.name, tag = t.tag, color = t.color, private = true, id = t.id } end

    local zones = {}
    for _, z in ipairs(Config.Zones) do
        local s = Gangwar.zones[z.key] or {}
        local owner = s.owner and Teams.info(Gangwar.refFromKey(s.owner))
        zones[#zones + 1] = {
            key = z.key, name = z.name, owner = s.owner or '',
            ownerName = owner and owner.name or 'Frei', ownerColor = owner and owner.color or nil,
            war = Gangwar.warByZone(z.key) ~= nil,
        }
    end

    local bans = DB.listBans()
    table.sort(bans, function(a, b) return (a.at or 0) > (b.at or 0) end)

    local cases = {}
    for _, c in ipairs(Config.Cases or {}) do cases[#cases + 1] = { key = c.key, name = c.name, color = c.color } end

    return {
        players = players, teams = teams, zones = zones,
        arenas = FFA.list(nil), bans = bans, now = os.time(),
        serverName = Config.ServerName, serverTag = Config.ServerTag,
        cases = cases,
        trolls = {
            { 'launch', 'Hochschleudern' }, { 'slap', 'Ohrfeige' }, { 'ragdoll', 'Umwerfen' }, { 'spin', 'Drehen' },
            { 'drunk', 'Betrunken' }, { 'dance', 'Tanzen lassen' }, { 'freeze', 'Einfrieren' }, { 'shake', 'Erdbeben' },
            { 'blind', 'Blenden' }, { 'clown', 'Trip' }, { 'eject', 'Aus dem Auto' }, { 'flip', 'Auto umdrehen' },
        },
        db = { mode = DB.mode, status = DB.status, pending = DB.pending and DB.pending() or 0, migrated = DB.migrated },
        me = Staff.view(src or 0),
    }
end

function Admin.send(src)
    TriggerClientEvent('bspvp:admin:data', src, Admin.payload(src))
end

-- Höhere Ränge kann man nicht kicken, bannen, muten oder trollen
local PROTECTED = { kick = true, ban = true, mute = true, troll = true, hood = true, bring = true, setRank = true }
local function outranked(src, action, args)
    if src == 0 or not PROTECTED[action] then return false end
    local acc
    if args.sid then
        local p = Players[int(args.sid)]
        acc = p and p.acc
    elseif args.uid ~= nil then
        acc = Accounts.get(args.uid)
    end
    if not acc then return false end
    if acc.id == (Players[src] and Players[src].acc and Players[src].acc.id) then return false end
    local mine = Staff.level(Staff.rank(src))
    return mine < Staff.level('owner') and Staff.level(Staff.rankOfAccount(acc)) >= mine
end

-- -----------------------------------------------------------------------
--  Aktionen
-- -----------------------------------------------------------------------
local function target(args)
    if args.sid then return Players[int(args.sid)] end
    if args.uid then return PlayerByUserId(args.uid) end
    return nil
end

local function account(args)
    if args.uid ~= nil then return Accounts.get(args.uid) end
    local p = target(args)
    return p and p.acc
end

local function refresh(acc)
    local p = PlayerByUserId(acc.id)
    if p then Accounts.push(p) end
    Accounts.save(acc)
end

local ACTIONS = {}

ACTIONS.heal = function(src, a)
    local p = target(a)
    if not p or p.dead then return 'Spieler nicht online oder tot.' end
    p.hp, p.armour = Config.MaxHealth, Config.MaxArmour
    SendVitals(p)
    return ('%s geheilt.'):format(p.acc.name)
end

ACTIONS.healAll = function()
    local n = 0
    for _, p in pairs(Players) do
        if p.loggedIn and not p.dead then
            p.hp, p.armour = Config.MaxHealth, Config.MaxArmour
            SendVitals(p)
            n = n + 1
        end
    end
    return ('%d Spieler geheilt.'):format(n)
end

ACTIONS.money = function(src, a)
    local acc, amount = account(a), tonumber(a.amount)
    if not acc or not amount then return 'Betrag fehlt.' end
    Accounts.addMoney(acc, amount)
    refresh(acc)
    return ('%s #%d hat jetzt $%s.'):format(acc.name, acc.id, Util.formatMoney(acc.money))
end

ACTIONS.xp = function(src, a)
    local acc, amount = account(a), tonumber(a.amount)
    if not acc or not amount then return 'XP fehlen.' end
    local p = PlayerByUserId(acc.id)
    if p then Accounts.addXp(p, amount) else acc.xp = math.max(0, acc.xp + int(amount)) end
    refresh(acc)
    return ('%s #%d ist jetzt Level %d.'):format(acc.name, acc.id, Accounts.level(acc))
end

ACTIONS.premium = function(src, a)
    local acc = account(a)
    if not acc then return 'Account nicht gefunden.' end
    -- days: Tage (0 = für immer); on = false nimmt es weg
    local days = a.on == false and -1 or (tonumber(a.days) or 0)
    Accounts.setPremium(acc, days)
    refresh(acc)
    local p = PlayerByUserId(acc.id)
    if p and acc.premium then Notify(p.src, 'success', ('Du hast jetzt Premium (%s)!'):format(Accounts.premiumText(acc))) end
    return ('%s: Premium %s.'):format(acc.name, Accounts.premiumText(acc))
end

ACTIONS.hood = function(src, a)
    local p = target(a)
    if not p or not p.team then return 'Spieler nicht online.' end
    Modes.set(p, 'lobby')
    Notify(p.src, 'info', 'Ein Admin hat dich zu deiner Hood geschickt.')
    return ('%s ist an seiner Hood.'):format(p.acc.name)
end

ACTIONS.kick = function(src, a)
    local p = target(a)
    if not p then return 'Spieler nicht online.' end
    local reason = Util.trim(a.reason)
    DropPlayer(p.src, ('Du wurdest gekickt. %s'):format(reason ~= '' and ('Grund: ' .. reason) or ''))
    return ('%s gekickt.'):format(p.acc and p.acc.name or ('#' .. p.src))
end

ACTIONS.ban = function(src, a)
    local acc = account(a)
    if not acc then return 'Account nicht gefunden.' end
    if not acc.license then return 'Für diesen Account ist keine Lizenz gespeichert.' end
    Admin.ban(src, acc, a.hours, a.reason)
    return ('%s #%d gebannt.'):format(acc.name, acc.id)
end

ACTIONS.unban = function(src, a)
    if type(a.license) ~= 'string' or not DB.getBan(a.license) then return 'Bann nicht gefunden.' end
    DB.setBan(a.license, nil)
    return 'Bann aufgehoben.'
end

ACTIONS.mute = function(src, a)
    local acc = account(a)
    local minutes = tonumber(a.minutes) or 0
    if not acc then return 'Account nicht gefunden.' end
    acc.mutedUntil = minutes > 0 and (os.time() + math.floor(minutes * 60)) or 0
    Accounts.save(acc)
    local p = PlayerByUserId(acc.id)
    if p then
        Notify(p.src, minutes > 0 and 'error' or 'info', minutes > 0 and ('Du bist für %d min stummgeschaltet.'):format(minutes) or 'Du darfst wieder schreiben.')
    end
    return minutes > 0 and ('%s ist %d min stumm.'):format(acc.name, minutes) or ('%s darf wieder schreiben.'):format(acc.name)
end

ACTIONS.zone = function(src, a)
    local z = Util.zone(a.key)
    if not z then return 'Gebiet nicht gefunden.' end
    local owner = a.owner ~= '' and a.owner or nil
    if not Gangwar.setOwner(z.key, owner) then return 'Team nicht gefunden.' end
    return ('%s gehört jetzt %s.'):format(z.name, owner or 'niemandem')
end

ACTIONS.endwar = function(src, a)
    if not Gangwar.forceEnd(a.key) then return 'Dort läuft kein Gangwar.' end
    return 'Gangwar beendet.'
end

ACTIONS.announce = function(src, a)
    local text = ChatSys.clean(a.text)
    if text == '' then return 'Text fehlt.' end
    Announce(-1, text)
    Chat(-1, '^1Ankündigung:^7 ' .. text)
    return 'Ankündigung gesendet.'
end

ACTIONS.clearArena = function(src, a)
    local n = FFA.clear(a.index and int(a.index) or nil)
    return ('%d Spieler zur Hood geschickt.'):format(n)
end

ACTIONS.disband = function(src, a)
    if not Teams.disband(nil, a.id) then return 'Team nicht gefunden oder gerade im Gangwar.' end
    return 'Team aufgelöst.'
end

ACTIONS.case = function(src, a)
    local acc = account(a)
    local c = Skins.case(tostring(a.case or ''))
    local n = math.max(1, math.min(50, int(a.amount or 1)))
    if not acc or not c then return 'Account oder Case nicht gefunden.' end
    acc.cases[c.key] = int(acc.cases[c.key]) + n
    refresh(acc)
    local p = PlayerByUserId(acc.id)
    if p then Notify(p.src, 'success', ('Du hast %dx %s bekommen – F2 → Cases.'):format(n, c.name)) end
    return ('%s #%d bekommt %dx %s.'):format(acc.name, acc.id, n, c.name)
end

ACTIONS.clearBounty = function(src, a)
    local acc = account(a)
    if not acc or Bounty.amount(acc.id) <= 0 then return 'Kein Kopfgeld auf diesem Spieler.' end
    Bounty.list[acc.id] = nil
    DB.set('bounty:' .. acc.id, nil)
    Bounty.syncState(acc.id)
    return ('Kopfgeld auf %s #%d gelöscht.'):format(acc.name, acc.id)
end

ACTIONS.endDuel = function(src, a)
    local p = target(a)
    if not p or not p.duelId then return 'Spieler ist in keinem Duell.' end
    Duels.leave(p, 'admin')
    return 'Duell beendet.'
end

-- Teleport: Admin zum Spieler / Spieler zum Admin (nur in derselben Welt sinnvoll)
ACTIONS.tpTo = function(src, a)
    local p, me = target(a), Players[src]
    if not p or not me then return 'Spieler nicht online.' end
    SetPlayerRoutingBucket(src, GetPlayerRoutingBucket(p.src))
    AntiCheat.allowMove(src, 8)
    local pos = GetEntityCoords(GetPlayerPed(p.src))
    TriggerClientEvent('bspvp:admin:teleport', src, { x = pos.x, y = pos.y, z = pos.z })
    return ('Zu %s teleportiert.'):format(p.acc.name)
end

ACTIONS.bring = function(src, a)
    local p = target(a)
    if not p or src == 0 then return 'Spieler nicht online.' end
    if GetPlayerRoutingBucket(p.src) ~= GetPlayerRoutingBucket(src) then return 'Der Spieler ist in einer anderen Welt (FFA/Gangwar/Duell).' end
    AntiCheat.allowMove(p.src, 8)
    local pos = GetEntityCoords(GetPlayerPed(src))
    TriggerClientEvent('bspvp:admin:teleport', p.src, { x = pos.x + 1.0, y = pos.y, z = pos.z })
    return ('%s zu dir geholt.'):format(p.acc.name)
end

-- -----------------------------------------------------------------------
--  Troll-Funktionen (harmlos: niemand verliert Leben, Geld oder Waffen)
-- -----------------------------------------------------------------------
local TROLLS = {
    launch = 'in die Luft geschleudert', ragdoll = 'umgeworfen', drunk = 'betrunken gemacht',
    spin = 'im Kreis gedreht', freeze = 'eingefroren', shake = 'durchgeschüttelt',
    blind = 'geblendet', dance = 'zum Tanzen gezwungen', eject = 'aus dem Auto geworfen',
    flip = 'samt Auto umgedreht', slap = 'geohrfeigt', clown = 'auf einen Trip geschickt',
}
ACTIONS.troll = function(src, a)
    local p = target(a)
    local kind = tostring(a.kind or '')
    if not p then return 'Spieler nicht online.' end
    if not TROLLS[kind] then return 'Diesen Troll gibt es nicht.' end
    AntiCheat.allowMove(p.src, 15)
    TriggerClientEvent('bspvp:troll', p.src, kind)
    return ('%s wurde %s.'):format(p.acc.name, TROLLS[kind])
end
Admin.trolls = TROLLS

ACTIONS.unbanId = function(src, a)
    local acc = account(a)
    if not acc or not acc.license or not DB.getBan(acc.license) then return 'Dieser Account ist nicht gebannt.' end
    DB.setBan(acc.license, nil)
    return ('%s #%d entbannt.'):format(acc.name, acc.id)
end

-- Rang vergeben (F6 → Spieler → Rang), ab Teamverwaltung, nur unter dem eigenen Rang
ACTIONS.setRank = function(src, a)
    local acc = account(a)
    if not acc then return 'Account nicht gefunden.' end
    local _, msg = Staff.setRank(src, acc, tostring(a.rank or ''))
    return msg
end

function Admin.run(src, action, args)
    local fn = ACTIONS[action]
    if not fn then return end
    args = type(args) == 'table' and args or {}
    -- Rang-Prüfung (Konsole und Discord-Bot zählen als Owner)
    if src ~= 0 and not Staff.can(src, action) then
        local need = Staff.info(Staff.need(action))
        local msg = ('Dafür reicht dein Rang nicht (ab %s).'):format(need and need.label or 'Admin')
        Notify(src, 'error', msg)
        return msg
    end
    if outranked(src, action, args) then
        local msg = 'Gegen ein gleich- oder höherrangiges Teammitglied geht das nicht.'
        Notify(src, 'error', msg)
        return msg
    end
    local ok, msg = pcall(fn, src, args)
    if not ok then
        print('^1[Admin] Fehler: ' .. tostring(msg) .. '^7')
        msg = 'Das hat nicht geklappt.'
    end
    if msg then
        log(src, ('%s -> %s'):format(action, msg))
        if src ~= 0 then Notify(src, 'info', msg) end
        Logs.add('admin', ('%s: **%s**'):format(src == 0 and adminName(0) or Logs.who(src), action), { { 'Ergebnis', msg } })
    end
    return msg
end

-- Aktion im Namen von jemandem ausführen (z. B. "Discord: Flamur")
function Admin.runAs(by, action, args)
    Admin.actor = by
    local ok, msg = pcall(Admin.run, 0, action, args)
    Admin.actor = nil
    return ok and msg or nil
end

-- -----------------------------------------------------------------------
--  Client -> Server
-- -----------------------------------------------------------------------
-- F6: Recht jedes Mal neu prüfen (so greifen neue add_principal-Zeilen sofort)
RegisterNetEvent('bspvp:admin:open', function()
    local src = source
    local allowed = IsAdmin(src)
    TriggerClientEvent('bspvp:admin:flag', src, allowed)
    if not allowed then
        return Notify(src, 'error', 'Du hast keine Admin-Rechte.')
    end
    Admin.send(src)
end)

RegisterNetEvent('bspvp:admin:action', function(action, args)
    local src = source
    if not IsAdmin(src) then
        return AntiCheat.flag(src, 'adminEvent', ('Admin-Aktion "%s" ohne Admin-Recht'):format(tostring(action):sub(1, 40)))
    end
    local p = Players[src]
    if p then
        local t = Now()
        if t - p.lastAction > 2000 then p.lastAction, p.actionCount = t, 0 end
        p.actionCount = p.actionCount + 1
        if p.actionCount > 15 then return end
    end
    Admin.run(src, tostring(action), args)
    Admin.send(src)
end)

AddEventHandler('bspvp:loggedIn', function(src)
    local allowed = IsAdmin(src)
    TriggerClientEvent('bspvp:admin:flag', src, allowed)
    local rank = Staff.info(Staff.rank(src))
    if rank then print(('^3[Team]^7 %s ist %s (F6).'):format(adminName(src), rank.label)) end
end)
