-- =======================================================================
--  Tägliche Missionen + Login-Bonus (7-Tage-Serie)
--  Ein "Tag" ist das Datum der Serverzeit. Die 3 Missionen eines Tages sind
--  pro Spieler fest (gleiche Auswahl nach einem Reconnect).
-- =======================================================================

Missions = {}

local int = Util.int
local function cfg() return Config.Missions or {} end

function Missions.today(offsetDays)
    return os.date('%Y-%m-%d', os.time() + (offsetDays or 0) * 86400)
end

-- Sekunden bis Mitternacht (Serverzeit)
function Missions.resetIn()
    local t = os.date('*t', os.time())
    return math.max(0, 86400 - (t.hour * 3600 + t.min * 60 + t.sec))
end

local function byId(id)
    for _, m in ipairs(cfg().list or {}) do
        if m.id == id then return m end
    end
    return nil
end
Missions.byId = byId

-- Feste Zufallsauswahl aus Datum + User-ID
local function pick(day, uid)
    local list = cfg().list or {}
    local n = math.min(int(cfg().perDay or 3), #list)
    local seed = (int(uid) * 7919 + 17) % 2147483647
    for i = 1, #day do seed = (seed * 31 + day:byte(i)) % 2147483647 end
    local pool = {}
    for i = 1, #list do pool[i] = i end
    local out = {}
    for _ = 1, n do
        seed = (seed * 1103515245 + 12345) % 2147483648
        local idx = (seed % #pool) + 1
        out[#out + 1] = list[pool[idx]]
        table.remove(pool, idx)
    end
    return out
end

-- Neuer Tag? Dann neue Missionen würfeln.
function Missions.ensure(acc)
    if not cfg().enabled then return false end
    local today = Missions.today()
    acc.daily = type(acc.daily) == 'table' and acc.daily or {}
    if acc.daily.day == today and type(acc.daily.list) == 'table' then return false end
    acc.daily = { day = today, list = {}, bonus = false }
    for _, m in ipairs(pick(today, acc.id)) do
        acc.daily.list[#acc.daily.list + 1] = { id = m.id, progress = 0, claimed = false }
    end
    return true
end

local function missionText(m)
    return (m.text or m.id):format(m.goal or 1)
end

-- Fortschritt zählen. stat 'streak' = Bestwert, alles andere wird addiert.
function Missions.track(acc, stat, amount, p)
    if not cfg().enabled or not acc then return end
    Missions.ensure(acc)
    amount = tonumber(amount) or 1
    for _, e in ipairs(acc.daily.list) do
        local m = byId(e.id)
        if m and m.stat == stat and not e.claimed then
            local before = int(e.progress)
            local now = stat == 'streak' and math.max(before, amount) or (before + amount)
            e.progress = math.min(int(now), int(m.goal))
            if before < m.goal and e.progress >= m.goal then
                p = p or PlayerByUserId(acc.id)
                if p then
                    TriggerClientEvent('bspvp:missionDone', p.src, { text = missionText(m), money = m.money or 0, xp = m.xp or 0 })
                end
            end
        end
    end
end

-- Belohnung (Geld, XP, Cases) gutschreiben -> kurzer Text dafür
function Missions.grant(acc, p, r)
    if type(r) ~= 'table' then return '' end
    local parts = {}
    if (r.money or 0) > 0 then
        Accounts.addMoney(acc, r.money)
        parts[#parts + 1] = '+$' .. Util.formatMoney(r.money)
    end
    if (r.xp or 0) > 0 then
        if p then Accounts.addXp(p, r.xp) else acc.xp = acc.xp + int(r.xp) end
        parts[#parts + 1] = ('+%d XP'):format(int(r.xp))
    end
    if r.case and Skins.case(r.case) then
        local n = math.max(1, int(r.cases or 1))
        acc.cases[r.case] = int(acc.cases[r.case]) + n
        parts[#parts + 1] = (n > 1 and (n .. 'x ') or '') .. Skins.case(r.case).name
    end
    return table.concat(parts, ', ')
end

function Missions.claim(p, index)
    local acc = p.acc
    Missions.ensure(acc)
    local e = acc.daily.list[int(index)]
    local m = e and byId(e.id)
    if not m then return Notify(p.src, 'error', 'Diese Mission gibt es nicht.') end
    if e.claimed then return Notify(p.src, 'error', 'Schon abgeholt.') end
    if int(e.progress) < m.goal then return Notify(p.src, 'error', 'Die Mission ist noch nicht geschafft.') end
    e.claimed = true
    local text = Missions.grant(acc, p, { money = m.money, xp = m.xp })
    Notify(p.src, 'success', ('%s: %s'):format(missionText(m), text))

    local all = true
    for _, x in ipairs(acc.daily.list) do
        if not x.claimed then all = false break end
    end
    if all and not acc.daily.bonus and cfg().allDoneBonus then
        acc.daily.bonus = true
        local bonus = Missions.grant(acc, p, cfg().allDoneBonus)
        Notify(p.src, 'level', ('Alle Tagesmissionen geschafft! Bonus: %s'):format(bonus))
    end
    Accounts.save(acc)
    Accounts.push(p)
end

-- -----------------------------------------------------------------------
--  Login-Serie
-- -----------------------------------------------------------------------
function Missions.login(acc)
    local today = Missions.today()
    acc.login = type(acc.login) == 'table' and acc.login or {}
    acc.login.streak = int(acc.login.streak)
    if acc.login.last ~= today then
        if acc.login.last == Missions.today(-1) then
            acc.login.streak = acc.login.streak + 1
        else
            acc.login.streak = 1
        end
        acc.login.last = today
    end
    return acc.login.claimed ~= today and #(Config.LoginRewards or {}) > 0
end

local function loginIndex(streak)
    local n = #(Config.LoginRewards or {})
    if n == 0 then return 0 end
    return ((math.max(1, streak) - 1) % n) + 1
end

function Missions.claimLogin(p)
    local acc = p.acc
    Missions.login(acc)
    local today = Missions.today()
    if acc.login.claimed == today then return Notify(p.src, 'error', 'Den Tagesbonus hast du heute schon abgeholt.') end
    local idx = loginIndex(acc.login.streak)
    local r = (Config.LoginRewards or {})[idx]
    if not r then return end
    acc.login.claimed = today
    local text = Missions.grant(acc, p, r)
    Notify(p.src, 'success', ('Tagesbonus Tag %d: %s'):format(idx, text))
    Accounts.save(acc)
    Accounts.push(p)
end

local function rewardView(r)
    if type(r) ~= 'table' then return nil end
    local c = r.case and Skins.case(r.case)
    return { money = r.money or 0, xp = r.xp or 0, case = c and c.key or nil, caseName = c and c.name or nil, caseColor = c and c.color or nil }
end
Missions.rewardView = rewardView

function Missions.view(acc)
    Missions.ensure(acc)
    Missions.login(acc)
    local list, done = {}, 0
    for i, e in ipairs(acc.daily and acc.daily.list or {}) do
        local m = byId(e.id)
        if m then
            local finished = int(e.progress) >= m.goal
            if e.claimed then done = done + 1 end
            list[#list + 1] = {
                index = i, id = m.id, text = missionText(m), stat = m.stat,
                progress = int(e.progress), goal = m.goal, money = m.money or 0, xp = m.xp or 0,
                done = finished, claimed = e.claimed == true,
            }
        end
    end
    local today = Missions.today()
    local idx = loginIndex(acc.login.streak)
    local days = {}
    for i, r in ipairs(Config.LoginRewards or {}) do
        local state = 'future'
        if i < idx or (i == idx and acc.login.claimed == today) then state = 'done'
        elseif i == idx then state = 'today' end
        local v = rewardView(r)
        v.day, v.state = i, state
        days[#days + 1] = v
    end
    return {
        enabled = cfg().enabled == true,
        list = list,
        claimedCount = done,
        bonus = rewardView(cfg().allDoneBonus),
        bonusDone = acc.daily and acc.daily.bonus == true,
        resetIn = Missions.resetIn(),
        login = { streak = acc.login.streak, day = idx, claimable = acc.login.claimed ~= today, days = days },
    }
end

-- Etwas abzuholen? (roter Punkt im Menü)
function Missions.pending(acc)
    if not acc or not acc.daily then return 0 end
    local n = 0
    for _, e in ipairs(acc.daily.list or {}) do
        local m = byId(e.id)
        if m and not e.claimed and int(e.progress) >= m.goal then n = n + 1 end
    end
    if acc.login and acc.login.claimed ~= Missions.today() then n = n + 1 end
    return n
end

-- -----------------------------------------------------------------------
--  Client -> Server
-- -----------------------------------------------------------------------
RegisterNetEvent('bspvp:missionClaim', function(index)
    local p = Guard(source)
    if not p then return end
    Missions.claim(p, index)
    Progress.sendMenu(p)
end)

RegisterNetEvent('bspvp:loginClaim', function()
    local p = Guard(source)
    if not p then return end
    Missions.claimLogin(p)
    Progress.sendMenu(p)
end)
