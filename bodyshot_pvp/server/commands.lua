-- =======================================================================
--  Befehle
-- =======================================================================

local int = Util.int

local function accountArg(arg)
    local uid = tonumber(arg)
    if not uid then return nil end
    return Accounts.get(uid)
end

-- Team-Befehle: gleiche Rang-Prüfung wie im Admin-Menü (Config.Staff.actions)
local function admin(src, action)
    if src == 0 or Staff.can(src, action or 'money') then return true end
    local need = Staff.info(Staff.need(action or 'money'))
    Reply(src, ('Dafür reicht dein Rang nicht (ab %s).'):format(need and need.label or 'Admin'))
    return false
end

-- Nach Admin-Änderungen: Spieler (falls online) aktualisieren
local function refresh(acc)
    local p = PlayerByUserId(acc.id)
    if p then Accounts.push(p) end
    Accounts.save(acc)
end

-- -----------------------------------------------------------------------
--  Spieler
-- -----------------------------------------------------------------------
-- FFA, Gangwar oder Duell verlassen -> zurück zur Hood
local LEAVE_TEXT = { ffa = 'FFA verlassen.', gangwar = 'Gangwar verlassen.', duel = 'Duell aufgegeben.' }
local function leaveTo(src, only)
    local p = Players[src]
    if not p or not p.loggedIn then return end
    if only and p.mode ~= only then
        return Reply(src, only == 'ffa' and 'Du bist in keinem FFA.' or 'Du bist in keinem Gangwar.')
    end
    if p.mode == 'ffa' or p.mode == 'gangwar' or p.mode == 'duel' then
        local text = LEAVE_TEXT[p.mode]
        Modes.set(p, 'lobby')
        Notify(src, 'info', text .. ' Du bist zurück an deiner Hood.')
    elseif p.mode == 'lobby' then
        Reply(src, 'Du bist schon an deiner Hood.')
    end
end
local function toHood(src) leaveTo(src) end
for _, name in ipairs({ 'hood', 'lobby', 'leave', 'verlassen' }) do RegisterCommand(name, toHood, false) end
for _, name in ipairs({ 'leaveffa', 'ffaverlassen', 'quitffa' }) do RegisterCommand(name, function(src) leaveTo(src, 'ffa') end, false) end
for _, name in ipairs({ 'leavegw', 'gwverlassen', 'leavegangwar', 'quitgw' }) do RegisterCommand(name, function(src) leaveTo(src, 'gangwar') end, false) end

-- /ffa [Nummer]: direkt einer Arena beitreten (ohne Nummer: die vollste mit freiem Platz)
RegisterCommand('ffa', function(src, args)
    local p = Guard(src)
    if not p then return end
    local index = tonumber(args[1])
    if not index then
        local best, bestCount = 1, -1
        for i, a in ipairs(Config.Arenas) do
            local n = FFA.count(i)
            if (a.max or 0) == 0 or n < a.max then
                if n > bestCount then best, bestCount = i, n end
            end
        end
        index = best
    end
    if not Config.Arenas[index] then
        return Reply(src, ('Arenen 1 bis %d: /ffa <Nummer>'):format(#Config.Arenas))
    end
    FFA.join(p, index)
end, false)

RegisterCommand('kill', function(src)
    local p = Players[src]
    if not p or not p.loggedIn or p.dead then return end
    if p.mode ~= 'ffa' and p.mode ~= 'gangwar' and not (p.mode == 'lobby' and Config.HoodCombat) then return end
    if Now() - p.lastSuicide < 5000 then
        return Reply(src, 'Warte kurz, bevor du /kill nochmal benutzt.')
    end
    p.lastSuicide = Now()
    Combat.handleDeath(p, nil, nil, 'suicide')
end, false)

RegisterCommand('id', function(src)
    local p = Players[src]
    if p and p.acc then
        Reply(src, ('Deine User-ID: #%d (Spieler-ID auf dem Server: %d)'):format(p.acc.id, src))
    end
end, false)

RegisterCommand('stats', function(src, args)
    local acc
    if args[1] then
        acc = accountArg(args[1])
    else
        local p = Players[src]
        acc = p and p.acc
    end
    if not acc then return Reply(src, 'Account nicht gefunden. Benutzung: /stats [User-ID]') end
    local s = acc.stats
    local kd = s.deaths > 0 and (s.kills / s.deaths) or s.kills
    Reply(src, ('%s #%d – Level %d | Kills: %d | Tode: %d | K/D: %.2f | Beste Serie: %d | Gangwars: %d/%d gewonnen'):format(
        acc.name, acc.id, Accounts.level(acc), s.kills, s.deaths, kd, s.best, s.gwWins, s.gwPlayed))
end, false)

-- /duell <User-ID> [Einsatz]   |   /duell annehmen   |   /duell ablehnen
local function duelCommand(src, args)
    local p = Guard(src)
    if not p then return end
    local first = string.lower(tostring(args[1] or ''))
    if first == 'annehmen' or first == 'ja' or first == 'accept' then return Duels.respond(p, true) end
    if first == 'ablehnen' or first == 'nein' or first == 'decline' then return Duels.respond(p, false) end
    if not tonumber(args[1]) then
        return Reply(src, 'Benutzung: /duell <User-ID> [Einsatz]  ·  /duell annehmen  ·  /duell ablehnen')
    end
    Duels.challenge(p, int(args[1]), 0, nil, tonumber(args[2]) or 0)
end
RegisterCommand('duell', duelCommand, false)
RegisterCommand('duel', duelCommand, false)

-- /kopfgeld <User-ID> <Betrag>
RegisterCommand('kopfgeld', function(src, args)
    local p = Guard(src)
    if not p then return end
    if not tonumber(args[1]) or not tonumber(args[2]) then
        return Reply(src, 'Benutzung: /kopfgeld <User-ID> <Betrag>')
    end
    Bounty.place(p, int(args[1]), int(args[2]))
end, false)

RegisterCommand('top', function(src)
    local list = Accounts.top(10)
    if #list == 0 then return Reply(src, 'Noch keine Kills auf dem Server.') end
    Reply(src, '^3Top 10 – Kills')
    for i, e in ipairs(list) do
        Reply(src, ('%d. %s #%d – %d Kills | K/D %.2f | Level %d'):format(i, e.name, e.id, e.kills, e.kd, e.level))
    end
end, false)

-- -----------------------------------------------------------------------
--  Admin  (Recht: add_ace group.admin bodyshot_pvp.admin allow)
-- -----------------------------------------------------------------------
RegisterCommand('heal', function(src, args)
    if not admin(src, 'heal') then return end
    local p
    if args[1] then
        local acc = accountArg(args[1])
        p = acc and PlayerByUserId(acc.id)
    else
        p = Players[src]
    end
    if not p or p.dead then return Reply(src, 'Spieler nicht online oder tot. Benutzung: /heal [User-ID]') end
    p.hp, p.armour = Config.MaxHealth, Config.MaxArmour
    SendVitals(p)
    Reply(src, ('%s wurde geheilt.'):format(p.acc.name))
end, false)

RegisterCommand('givemoney', function(src, args)
    if not admin(src, 'money') then return end
    local acc, amount = accountArg(args[1]), tonumber(args[2])
    if not acc or not amount then return Reply(src, 'Benutzung: /givemoney <User-ID> <Betrag>') end
    Accounts.addMoney(acc, amount)
    refresh(acc)
    Reply(src, ('%s #%d hat jetzt $%s.'):format(acc.name, acc.id, Util.formatMoney(acc.money)))
end, false)

RegisterCommand('givexp', function(src, args)
    if not admin(src, 'xp') then return end
    local acc, amount = accountArg(args[1]), tonumber(args[2])
    if not acc or not amount then return Reply(src, 'Benutzung: /givexp <User-ID> <XP>') end
    local p = PlayerByUserId(acc.id)
    if p then
        Accounts.addXp(p, amount)
    else
        acc.xp = math.max(0, acc.xp + int(amount))
    end
    refresh(acc)
    Reply(src, ('%s #%d ist jetzt Level %d (%d XP).'):format(acc.name, acc.id, Accounts.level(acc), acc.xp))
end, false)

-- /givecase <User-ID> <street|mk2|gold> [Anzahl]
RegisterCommand('givecase', function(src, args)
    if not admin(src, 'case') then return end
    local acc = accountArg(args[1])
    local c = Skins.case(tostring(args[2] or ''))
    local n = math.max(1, math.min(50, int(args[3] or 1)))
    if not acc or not c then return Reply(src, 'Benutzung: /givecase <User-ID> <street|mk2|gold> [Anzahl]') end
    acc.cases[c.key] = int(acc.cases[c.key]) + n
    refresh(acc)
    Reply(src, ('%s #%d bekommt %dx %s.'):format(acc.name, acc.id, n, c.name))
    local p = PlayerByUserId(acc.id)
    if p then Notify(p.src, 'success', ('Du hast %dx %s bekommen – F2 → Cases.'):format(n, c.name)) end
end, false)

RegisterCommand('premium', function(src, args)
    if not admin(src, 'premium') then return end
    -- /premium <User-ID> <Tage>   (0 = für immer, -1 = wegnehmen, ohne Tage = für immer)
    local acc = accountArg(args[1])
    if not acc then return Reply(src, 'Benutzung: /premium <User-ID> <Tage>  (0 = für immer, -1 = wegnehmen)') end
    local days = tonumber(args[2]) or 0
    Accounts.setPremium(acc, days)
    refresh(acc)
    local p = PlayerByUserId(acc.id)
    if p and acc.premium then Notify(p.src, 'success', ('Du hast jetzt Premium (%s)!'):format(Accounts.premiumText(acc))) end
    Reply(src, ('%s #%d: Premium %s.'):format(acc.name, acc.id, Accounts.premiumText(acc)))
    Logs.add('admin', ('%s: Premium für %s #%d -> %s'):format(Logs.who(src), acc.name, acc.id, Accounts.premiumText(acc)))
end, false)

RegisterCommand('setzone', function(src, args)
    if not admin(src, 'zone') then return end
    local zoneKey, team = args[1], args[2]
    if not zoneKey or not team or not Util.zone(zoneKey) then
        local keys = {}
        for _, z in ipairs(Config.Zones) do keys[#keys + 1] = z.key end
        return Reply(src, 'Benutzung: /setzone <Gebiet> <Gang-ID | p<Team-Nr> | frei>  – Gebiete: ' .. table.concat(keys, ', '))
    end
    local key
    if team ~= 'frei' then
        if team:match('^p%d+$') then
            key = 'private:' .. team:sub(2)
        else
            key = 'gang:' .. team
        end
    end
    if Gangwar.setOwner(zoneKey, key) then
        Reply(src, ('%s gehört jetzt %s.'):format(Util.zone(zoneKey).name, key or 'niemandem'))
    else
        Reply(src, 'Team nicht gefunden.')
    end
end, false)

RegisterCommand('endwar', function(src, args)
    if not admin(src, 'endwar') then return end
    if not args[1] or not Gangwar.forceEnd(args[1]) then
        return Reply(src, 'Benutzung: /endwar <Gebiet> (nur wenn dort gerade gekämpft wird)')
    end
    Reply(src, 'Gangwar beendet.')
end, false)

-- Hood-Punkte im Spiel setzen: an die Stelle stellen und eingeben
-- /sethood spawn|garage|car|reset [Team, z. B. ballas oder p3]
RegisterCommand('sethood', function(src, args)
    if not admin(src, 'sethood') then return end
    local what = args[1]
    local p = Players[src]
    local ref
    if args[2] then
        if args[2]:match('^p%d+$') then ref = { kind = 'private', id = int(args[2]:sub(2)) }
        elseif Util.gang(args[2]) then ref = { kind = 'gang', id = args[2] } end
    else
        ref = p and p.team
    end
    if not ref or not Teams.info(ref) then return Reply(src, 'Team nicht gefunden. Benutzung: /sethood spawn|garage|car|reset [Gang-ID oder p<Nr>]') end
    if what == 'reset' then
        Hoods.reset(ref)
        return Reply(src, 'Hood zurück auf die Config-Werte gesetzt.')
    end
    if what ~= 'spawn' and what ~= 'garage' and what ~= 'car' then
        return Reply(src, 'Benutzung: /sethood spawn|garage|car|reset [Gang-ID oder p<Nr>]')
    end
    if src == 0 then return Reply(src, 'Das geht nur im Spiel.') end
    local ped = GetPlayerPed(src)
    local c = GetEntityCoords(ped)
    local h = GetEntityHeading(ped)
    Hoods.set(ref, what, c, h)
    Reply(src, ('Hood von %s: %s gesetzt (%.1f, %.1f, %.1f).'):format(Teams.info(ref).name, what, c.x, c.y, c.z))
end, false)

RegisterCommand('kick', function(src, args)
    if not admin(src, 'kick') then return end
    local acc = accountArg(args[1])
    if not acc then return Reply(src, 'Benutzung: /kick <User-ID> [Grund]') end
    Admin.run(src, 'kick', { uid = acc.id, reason = table.concat(args, ' ', 2) })
end, false)

RegisterCommand('ban', function(src, args)
    if not admin(src, 'ban') then return end
    local acc, hours = accountArg(args[1]), tonumber(args[2])
    if not acc or not hours then return Reply(src, 'Benutzung: /ban <User-ID> <Stunden, 0 = für immer> [Grund]') end
    Admin.run(src, 'ban', { uid = acc.id, hours = hours, reason = table.concat(args, ' ', 3) })
end, false)

RegisterCommand('unban', function(src, args)
    if not admin(src, 'unban') then return end
    local acc = accountArg(args[1])
    if not acc or not acc.license then return Reply(src, 'Benutzung: /unban <User-ID>') end
    Admin.run(src, 'unban', { license = acc.license })
end, false)

RegisterCommand('mute', function(src, args)
    if not admin(src, 'mute') then return end
    local acc, minutes = accountArg(args[1]), tonumber(args[2])
    if not acc or not minutes then return Reply(src, 'Benutzung: /mute <User-ID> <Minuten, 0 = aufheben>') end
    Admin.run(src, 'mute', { uid = acc.id, minutes = minutes })
end, false)

RegisterCommand('announce', function(src, args)
    if not admin(src, 'announce') then return end
    Admin.run(src, 'announce', { text = table.concat(args, ' ') })
end, false)

-- -----------------------------------------------------------------------
--  F11: alle Tasten und Befehle (Teammitglieder sehen zusätzlich ihre)
-- -----------------------------------------------------------------------
local function helpData(src)
    local k = Config.Keys or {}
    local it = Config.Items or {}
    local sections = {
        { title = 'Tasten', items = {
            { cmd = k.teams or 'F1', key = true, text = 'Teams wählen und wechseln (an der Hood)' },
            { cmd = k.menu or 'F2', key = true, text = 'Hauptmenü: FFA, Gangwar, Inventar, Shop, Battlepass …' },
            { cmd = k.repair or 'F3', key = true, text = 'Fahrzeug reparieren (an der Hood)' },
            { cmd = k.interact or 'E', key = true, text = 'Garage an der Hood und am Gangwar-Spawn' },
            { cmd = (it.vest and it.vest.key) or 'G', key = true, text = 'Weste ziehen (3,5 s)' },
            { cmd = (it.medkit and it.medkit.key) or 'H', key = true, text = 'Medkit benutzen (3,5 s)' },
            { cmd = (Config.Emotes and Config.Emotes.key) or 'K', key = true, text = 'Emotes & Tänze' },
            { cmd = k.chat or 'T', key = true, text = 'Chat (Tab = Alle/Team)' },
            { cmd = k.duelAccept or 'Y', key = true, text = 'Duell annehmen' },
            { cmd = k.duelDecline or 'X', key = true, text = 'Duell ablehnen' },
            { cmd = 'F11', key = true, text = 'Diese Hilfe' },
        } },
        { title = 'Befehle', items = {
            { cmd = '/hood', text = 'Zurück zu deiner Hood' },
            { cmd = '/leave', text = 'FFA, Gangwar oder Duell verlassen' },
            { cmd = '/leaveffa', text = 'Nur das FFA verlassen' },
            { cmd = '/leavegw', text = 'Nur den Gangwar verlassen' },
            { cmd = '/ffa [Nummer]', text = 'Einer FFA-Arena beitreten' },
            { cmd = '/gangwar', text = 'Gangwar-Seite öffnen' },
            { cmd = '/kill', text = 'Neu spawnen (zählt als Tod)' },
            { cmd = '/t <Text>', text = 'Nachricht an dein Team' },
            { cmd = '/id', text = 'Deine User-ID (= dein Einladungs-Code)' },
            { cmd = '/stats [User-ID]', text = 'Statistik von dir oder einem anderen' },
            { cmd = '/top', text = 'Top 10 nach Kills' },
            { cmd = '/duell <User-ID> [Einsatz]', text = '1v1-Duell fordern' },
            { cmd = '/kopfgeld <User-ID> <Betrag>', text = 'Kopfgeld setzen' },
            { cmd = '/inventar', text = 'Inventar öffnen' },
            { cmd = '/kleidung', text = 'Kleiderschrank (an der Hood)' },
            { cmd = '/gluecksrad', text = 'Tägliches Glücksrad' },
            { cmd = '/einladen', text = 'Freunde einladen' },
            { cmd = '/e <name>', text = 'Emote abspielen, /e stop beendet' },
            { cmd = '/weste', text = 'Weste ziehen' },
            { cmd = '/medkit', text = 'Medkit benutzen' },
        } },
    }
    local rank = Staff.info(Staff.rank(src))
    if rank then
        local staff = {}
        local list = {
            { 'heal', '/heal [User-ID]', 'Heilen' }, { 'mute', '/mute <User-ID> <Minuten>', 'Stummschalten (0 = aufheben)' },
            { 'kick', '/kick <User-ID> [Grund]', 'Kicken' }, { 'ban', '/ban <User-ID> <Stunden> [Grund]', 'Bannen (0 = für immer)' },
            { 'unban', '/unban <User-ID>', 'Bann aufheben' }, { 'zone', '/setzone <Gebiet> <Team>', 'Gebietsbesitzer setzen' },
            { 'endwar', '/endwar <Gebiet>', 'Gangwar beenden' }, { 'sethood', '/sethood spawn|garage|car', 'Hood-Punkte setzen' },
            { 'announce', '/announce <Text>', 'Ankündigung an alle' }, { 'setRank', '/rang <User-ID> <rang|keiner>', 'Team-Rang vergeben' },
            { 'money', '/givemoney <User-ID> <Betrag>', 'Geld geben' }, { 'xp', '/givexp <User-ID> <XP>', 'XP geben' },
            { 'case', '/givecase <User-ID> <Case> [Anzahl]', 'Case geben' }, { 'premium', '/premium <User-ID> <Tage>', 'Premium (0 = für immer, -1 = weg)' },
        }
        staff[#staff + 1] = { cmd = k.admin or 'F6', key = true, text = 'Admin-Menü' }
        for _, e in ipairs(list) do
            if Staff.can(src, e[1]) then staff[#staff + 1] = { cmd = e[2], text = e[3] } end
        end
        sections[#sections + 1] = { title = 'Team', rank = rank, items = staff }
    end
    return { sections = sections }
end

RegisterNetEvent('bspvp:help', function()
    local src = source
    if Players[src] then TriggerClientEvent('bspvp:help', src, helpData(src)) end
end)

-- /rang <User-ID> <support|moderator|gangverwaltung|teamverwaltung|admin|owner|keiner>
RegisterCommand('rang', function(src, args)
    if not admin(src, 'setRank') then return end
    local acc = accountArg(args[1])
    local key = string.lower(tostring(args[2] or ''))
    if key == 'keiner' or key == 'none' or key == '0' then key = '' end
    if not acc or (key ~= '' and not Staff.byKey[key]) then
        local keys = {}
        for _, r in ipairs(Staff.list) do keys[#keys + 1] = r.key end
        return Reply(src, 'Benutzung: /rang <User-ID> <' .. table.concat(keys, '|') .. '|keiner>')
    end
    local msg = Admin.run(src, 'setRank', { uid = acc.id, rank = key })
    if src == 0 and msg then print(msg) end
end, false)

-- Teamchat per Befehl
RegisterCommand('t', function(src, args)
    local p = Players[src]
    if p and p.loggedIn then ChatSys.send(p, 'team', table.concat(args, ' ')) end
end, false)
