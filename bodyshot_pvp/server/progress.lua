-- =======================================================================
--  Waffenshop, Battlepass, Menü-Daten und Team-Aktionen
-- =======================================================================

Progress = {}

local int = Util.int

-- Waffe sofort ins Inventar legen (Hood, FFA und Gangwar)
local function giveNow(p, weaponName)
    if not p.dead and (p.mode == 'ffa' or p.mode == 'gangwar' or p.mode == 'lobby') then
        TriggerClientEvent('bspvp:giveWeapon', p.src, weaponName)
    end
end

-- -----------------------------------------------------------------------
--  Waffenshop (einmal kaufen = für immer)
-- -----------------------------------------------------------------------
function Progress.shopView(acc)
    local out = {}
    for _, w in ipairs(Weapons.list) do
        out[#out + 1] = {
            name = w.name,
            label = w.label,
            price = w.price,
            damage = w.damage,
            shots = w.realShots,
            mk2 = w.name:find('_MK2', 1, true) ~= nil,
            owned = Accounts.owns(acc, w.name),
        }
    end
    return out
end

function Progress.buyWeapon(p, name)
    local w = Weapons.get(name)
    if not w then return Notify(p.src, 'error', 'Diese Waffe gibt es nicht.') end
    if Accounts.owns(p.acc, w.name) then return Notify(p.src, 'error', 'Die hast du schon.') end
    if p.acc.money < w.price then
        return Notify(p.src, 'error', ('Dir fehlen $%s.'):format(Util.formatMoney(w.price - p.acc.money)))
    end
    Accounts.addMoney(p.acc, -w.price)
    p.acc.weapons[#p.acc.weapons + 1] = w.name
    Accounts.save(p.acc)
    Accounts.push(p)
    giveNow(p, w.name)
    Notify(p.src, 'success', ('%s gekauft – gehört dir jetzt für immer.'):format(w.label))
    Logs.add('shop', ('%s kauft **%s** für $%s'):format(Logs.who(p), w.label, Util.formatMoney(w.price)))
end

-- -----------------------------------------------------------------------
--  Battlepass
-- -----------------------------------------------------------------------
local function isClaimed(acc, track, level)
    for _, l in ipairs(acc.claimed[track]) do
        if l == level then return true end
    end
    return false
end

local function rewardView(r)
    if not r then return nil end
    if r.case then
        local c = Skins.case(r.case)
        return { kind = 'case', label = c and c.name or tostring(r.case), color = c and c.color or nil }
    end
    if r.weapon then
        local w = Weapons.get(r.weapon)
        return { kind = 'weapon', label = w and w.label or tostring(r.weapon) }
    end
    return { kind = 'money', label = '$' .. Util.formatMoney(r.money or 0) }
end

function Progress.battlepassView(acc)
    local level = Accounts.level(acc)
    local tiers = {}
    for lvl = 1, Util.maxLevel() do
        local tier = Config.Battlepass.rewards[lvl]
        if tier then
            tiers[#tiers + 1] = {
                level = lvl,
                reached = level >= lvl,
                free = rewardView(tier.free),
                premium = rewardView(tier.premium),
                freeClaimed = isClaimed(acc, 'free', lvl),
                premiumClaimed = isClaimed(acc, 'premium', lvl),
            }
        end
    end
    return {
        name = Config.Battlepass.name,
        level = level,
        xp = acc.xp,
        xpPerLevel = Config.Battlepass.xpPerLevel,
        progress = Util.levelProgress(acc.xp),
        maxLevel = Util.maxLevel(),
        premium = acc.premium,
        tiers = tiers,
    }
end

function Progress.claim(p, track, level)
    level = int(level)
    if track ~= 'free' and track ~= 'premium' then return end
    local tier = Config.Battlepass.rewards[level]
    local reward = tier and tier[track]
    if not reward then return Notify(p.src, 'error', 'Diese Belohnung gibt es nicht.') end
    Accounts.syncPremium(p.acc)
    if track == 'premium' and not p.acc.premium then return Notify(p.src, 'error', 'Dafür brauchst du den Premium-Pass.') end
    if Accounts.level(p.acc) < level then return Notify(p.src, 'error', ('Erst ab Level %d.'):format(level)) end
    if isClaimed(p.acc, track, level) then return Notify(p.src, 'error', 'Schon abgeholt.') end

    table.insert(p.acc.claimed[track], level)
    local text
    if reward.case then
        text = Missions.grant(p.acc, p, { case = reward.case }) .. ' – öffnen unter F2 → Cases'
    elseif reward.weapon then
        local w = Weapons.get(reward.weapon)
        if w and not Accounts.owns(p.acc, w.name) then
            p.acc.weapons[#p.acc.weapons + 1] = w.name
            giveNow(p, w.name)
            text = ('%s freigeschaltet!'):format(w.label)
        else
            local money = Config.Battlepass.duplicateMoney or 0
            Accounts.addMoney(p.acc, money)
            text = ('Waffe schon im Besitz – dafür +$%s'):format(Util.formatMoney(money))
        end
    else
        Accounts.addMoney(p.acc, reward.money or 0)
        text = ('+$%s'):format(Util.formatMoney(reward.money or 0))
    end
    Accounts.save(p.acc)
    Accounts.push(p)
    Notify(p.src, 'success', ('Level %d: %s'):format(level, text))
end

-- -----------------------------------------------------------------------
--  Menü (F2)
-- -----------------------------------------------------------------------
local MODE_NAMES = { lobby = 'Hood', ffa = 'FFA', gangwar = 'Gangwar', select = 'Teamwahl', login = 'Login', duel = '1v1-Duell' }

function Progress.placeName(q)
    local place = MODE_NAMES[q.mode] or q.mode
    if q.mode == 'ffa' and q.arena and Config.Arenas[q.arena] then place = 'FFA ' .. Config.Arenas[q.arena].name end
    return place
end

function Progress.playersView()
    local out = {}
    for _, q in pairs(Players) do
        if q.loggedIn and q.acc then
            local info = Teams.info(q.team)
            local place = Progress.placeName(q)
            out[#out + 1] = {
                id = q.acc.id, name = q.acc.name,
                tag = info and info.tag or nil, color = info and info.color or nil, team = info and info.name or nil,
                place = place, level = Accounts.level(q.acc), kills = q.acc.stats.kills,
                ping = GetPlayerPing and GetPlayerPing(q.src) or 0,
                bounty = Bounty.amount(q.acc.id),
            }
        end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

function Progress.menuPayload(p)
    local war = p.warId and Gangwar.wars[p.warId]
    local hood = p.team and Hoods.get(p.team)
    return {
        serverName = Config.ServerName,
        serverTag = Config.ServerTag,
        account = Accounts.view(p.acc),
        mode = p.mode,
        team = Teams.menuView(p),
        arenas = FFA.list(p),
        zones = Gangwar.menuView(p),
        lobby = hood and { x = hood.spawn.x, y = hood.spawn.y, name = hood.name } or nil,
        hoods = Hoods.mapView(),
        discord = Config.Links and Config.Links.discord or '',
        rules = {
            pointsPerKill = Config.Gangwar.pointsPerKill or 1,
            fightMinutes = Config.Gangwar.fightMinutes or 10,
            incomePerZone = Config.Gangwar.incomePerZone or 0,
            incomeMinutes = Config.Gangwar.incomeMinutes or 0,
        },
        rulesText = Config.Rules or {},
        war = war and Gangwar.statePayload(war) or nil,
        shop = Progress.shopView(p.acc),
        battlepass = Progress.battlepassView(p.acc),
        top = Accounts.top(10),
        players = Progress.playersView(),
        online = OnlineCount(),
        hud = Config.Hud,
        daily = Missions.view(p.acc),
        cases = Cases.view(p.acc),
        garage = Garage.view(p, 'hood'),
        wheel = Wheel.view(p.acc),
        items = Items.view(p.acc),
        attachments = Attachments.view(p.acc),
        referral = Referral.view(p.acc),
        wardrobe = Config.Wardrobe and Config.Wardrobe.enabled ~= false,
        emotes = (function()
            local out = {}
            for _, e in ipairs(EmoteList or {}) do out[#out + 1] = { name = e.name, label = e.label, group = e.group } end
            return out
        end)(),
        emotesAllowed = Config.Emotes and Config.Emotes.enabled ~= false and (p.mode == 'lobby' or Config.Emotes.inCombat == true),
        duels = Duels.view(p),
        bounty = Bounty.view(p),
    }
end

function Progress.sendMenu(p)
    if p and p.loggedIn then
        TriggerClientEvent('bspvp:menuData', p.src, Progress.menuPayload(p))
    end
end

-- -----------------------------------------------------------------------
--  Client -> Server
-- -----------------------------------------------------------------------
RegisterNetEvent('bspvp:menu', function()
    local p = Guard(source)
    if p then Progress.sendMenu(p) end
end)

RegisterNetEvent('bspvp:buyWeapon', function(name)
    local p = Guard(source)
    if not p then return end
    Progress.buyWeapon(p, tostring(name))
    Progress.sendMenu(p)
end)

RegisterNetEvent('bspvp:bpClaim', function(track, level)
    local p = Guard(source)
    if not p then return end
    Progress.claim(p, tostring(track), level)
    Progress.sendMenu(p)
end)

-- Team-Aktionen aus dem Menü
local teamActions = {
    create  = function(p, a) Teams.create(p, a.name, a.tag, a.color) end,
    invite  = function(p, a) Teams.invite(p, int(a.id)) end,
    accept  = function(p) Teams.acceptInvite(p) end,
    decline = function(p) Teams.declineInvite(p) end,
    kick    = function(p, a) Teams.kick(p, int(a.id)) end,
    leave   = function(p) Teams.leave(p) end,
    disband = function(p) Teams.disband(p) end,
}

RegisterNetEvent('bspvp:team', function(action, args)
    local p = Guard(source)
    if not p then return end
    local fn = teamActions[tostring(action)]
    if not fn then return end
    fn(p, type(args) == 'table' and args or {})
    Progress.sendMenu(p)
end)

RegisterNetEvent('bspvp:changeTeam', function()
    local p = Guard(source)
    if not p then return end
    if p.mode ~= 'lobby' then
        return Notify(p.src, 'error', 'Teams wechselst du an deiner Hood.')
    end
    TriggerClientEvent('bspvp:teamSelect', p.src, Teams.selectPayload(p))
end)
