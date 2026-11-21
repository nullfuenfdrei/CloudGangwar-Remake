-- =======================================================================
--  Kopfgeld
--  Spieler setzen Geld auf andere (stapelt sich). Wer den Gesuchten im FFA
--  oder Gangwar tötet, bekommt alles. Killserien geben automatisch Kopfgeld.
--  Gespeichert unter bounty:<User-ID> (MySQL: bs_bounties).
-- =======================================================================

Bounty = { list = {} }    -- [uid] = { amount, auto, from = { [uid] = Betrag }, updated }

local int = Util.int
local function cfg() return Config.Bounty or {} end

function Bounty.load()
    Bounty.list = {}
    for _, key in ipairs(DB.keys('bounty:')) do
        local b = DB.get(key)
        local uid = tonumber(key:sub(8))
        if uid and type(b) == 'table' and int(b.amount) > 0 then
            b.amount = int(b.amount)
            b.auto = int(b.auto)
            b.from = type(b.from) == 'table' and b.from or {}
            Bounty.list[int(uid)] = b
        end
    end
end

local function save(uid)
    local b = Bounty.list[uid]
    DB.set('bounty:' .. uid, (b and b.amount > 0) and b or nil)
end

function Bounty.amount(uid)
    local b = Bounty.list[int(uid)]
    return b and b.amount or 0
end

-- Kopfgeld als State-Bag, damit Clients es über dem Kopf zeigen können
function Bounty.syncState(uid)
    local p = PlayerByUserId(uid)
    if p then Player(p.src).state:set('gwBounty', Bounty.amount(uid), true) end
end

function Bounty.add(uid, amount, fromUid, auto)
    uid, amount = int(uid), int(amount)
    if amount <= 0 then return end
    local b = Bounty.list[uid] or { amount = 0, auto = 0, from = {} }
    b.amount = b.amount + amount
    if auto then
        b.auto = int(b.auto) + amount
    elseif fromUid ~= nil then
        local k = tostring(int(fromUid))
        b.from[k] = int(b.from[k]) + amount
    end
    b.updated = os.time()
    Bounty.list[uid] = b
    save(uid)
    Bounty.syncState(uid)
    return b.amount
end

-- Spieler setzt Kopfgeld
function Bounty.place(p, targetUid, amount)
    if not cfg().enabled then return Notify(p.src, 'error', 'Kopfgeld ist ausgeschaltet.') end
    targetUid, amount = int(targetUid), int(amount)
    local target = Accounts.get(targetUid)
    if not target then return Notify(p.src, 'error', 'Diese User-ID gibt es nicht.') end
    if target.id == p.acc.id then return Notify(p.src, 'error', 'Auf dich selbst kannst du kein Kopfgeld setzen.') end
    if amount < (cfg().min or 1) then
        return Notify(p.src, 'error', ('Mindestens $%s.'):format(Util.formatMoney(cfg().min or 1)))
    end
    if amount > (cfg().max or amount) then
        return Notify(p.src, 'error', ('Höchstens $%s auf einmal.'):format(Util.formatMoney(cfg().max)))
    end
    if p.acc.money < amount then
        return Notify(p.src, 'error', ('Dir fehlen $%s.'):format(Util.formatMoney(amount - p.acc.money)))
    end
    Accounts.addMoney(p.acc, -amount)
    p.acc.stats.bountyPlaced = int(p.acc.stats.bountyPlaced) + amount
    Accounts.save(p.acc)
    Accounts.push(p)
    local total = Bounty.add(target.id, amount, p.acc.id, false)
    Missions.track(p.acc, 'bountyPlace', 1, p)
    Notify(p.src, 'success', ('$%s Kopfgeld auf %s gesetzt (gesamt $%s).'):format(Util.formatMoney(amount), target.name, Util.formatMoney(total)))
    local tp = PlayerByUserId(target.id)
    if tp then Notify(tp.src, 'war', ('Auf dich ist jetzt ein Kopfgeld von $%s ausgesetzt!'):format(Util.formatMoney(total))) end
    if total >= (cfg().announce or math.huge) then
        Announce(-1, ('Kopfgeld: $%s auf %s'):format(Util.formatMoney(total), target.name))
    end
    Chat(-1, ('^1Kopfgeld:^7 %s setzt ^2$%s^7 auf ^3%s^7 #%d (gesamt $%s)'):format(p.acc.name, Util.formatMoney(amount), target.name, target.id, Util.formatMoney(total)))
end

-- Killserie -> automatisches Kopfgeld
function Bounty.onStreak(p, streak)
    if not cfg().enabled then return end
    local add = (cfg().streak or {})[streak]
    if not add or add <= 0 then return end
    local total = Bounty.add(p.acc.id, add, nil, true)
    Notify(p.src, 'war', ('%d Kills in Folge: auf dich sind jetzt $%s Kopfgeld!'):format(streak, Util.formatMoney(total)))
    for _, q in ipairs(Modes.sameWorld(p)) do
        if q ~= p then Notify(q.src, 'war', ('%s ist auf einer %der-Serie – $%s Kopfgeld!'):format(p.acc.name, streak, Util.formatMoney(total))) end
    end
end

-- Kill im FFA/Gangwar: Kopfgeld kassieren
function Bounty.onKill(killer, victim)
    if not cfg().enabled or not killer or not victim or killer == victim then return end
    local uid = victim.acc.id
    local b = Bounty.list[uid]
    if not b or b.amount <= 0 then return end
    local amount = b.amount
    Bounty.list[uid] = nil
    save(uid)
    Bounty.syncState(uid)
    Accounts.addMoney(killer.acc, amount)
    killer.acc.stats.bounties = int(killer.acc.stats.bounties) + 1
    killer.acc.stats.bountyEarned = int(killer.acc.stats.bountyEarned) + amount
    Missions.track(killer.acc, 'bountyClaim', 1, killer)
    DB.log('bounty', { target_id = uid, hunter_id = killer.acc.id, amount = amount })
    TriggerClientEvent('bspvp:bountyClaimed', killer.src, { victim = victim.acc.name, amount = amount })
    Notify(victim.src, 'info', ('%s hat dein Kopfgeld von $%s kassiert.'):format(killer.acc.name, Util.formatMoney(amount)))
    Chat(-1, ('^1Kopfgeld:^7 ^3%s^7 kassiert ^2$%s^7 für ^3%s^7'):format(killer.acc.name, Util.formatMoney(amount), victim.acc.name))
    if amount >= (cfg().announce or math.huge) then
        Announce(-1, ('%s kassiert $%s Kopfgeld für %s'):format(killer.acc.name, Util.formatMoney(amount), victim.acc.name))
    end
    return amount
end

-- Liste fürs Menü (höchste zuerst)
function Bounty.view(p)
    local out = {}
    for uid, b in pairs(Bounty.list) do
        local acc = Accounts.get(uid)
        if acc and b.amount > 0 then
            local q = PlayerByUserId(uid)
            local info = q and Teams.info(q.team)
            local mine = p and int(b.from[tostring(p.acc.id)]) or 0
            out[#out + 1] = {
                id = uid, name = acc.name, amount = b.amount, auto = int(b.auto), mine = mine,
                online = q ~= nil, place = q and Progress.placeName(q) or nil,
                tag = info and info.tag or nil, color = info and info.color or nil,
                level = Accounts.level(acc), kills = acc.stats.kills,
                me = p and uid == p.acc.id or false,
            }
        end
    end
    table.sort(out, function(a, b)
        if a.amount ~= b.amount then return a.amount > b.amount end
        return a.id < b.id
    end)
    for i = #out, 31, -1 do out[i] = nil end
    local streak = {}
    for n, amount in pairs(cfg().streak or {}) do streak[#streak + 1] = { streak = int(n), amount = int(amount) } end
    table.sort(streak, function(a, b) return a.streak < b.streak end)
    return {
        enabled = cfg().enabled == true, list = out, min = cfg().min or 1000, max = cfg().max or 100000,
        streak = streak, onMe = p and Bounty.amount(p.acc.id) or 0,
    }
end

RegisterNetEvent('bspvp:bountyPlace', function(targetUid, amount)
    local p = Guard(source)
    if not p then return end
    Bounty.place(p, targetUid, amount)
    Progress.sendMenu(p)
end)
