-- =======================================================================
--  Glücksrad: einmal alle 24 Stunden drehen
--  Der Server zieht den Gewinn und schreibt ihn sofort gut. Der Client
--  bekommt nur das Feld, auf dem das Rad stehen bleiben soll.
-- =======================================================================

Wheel = {}

local int = Util.int

local function cfg() return Config.Wheel or {} end

local function cooldown() return math.floor((cfg().cooldownHours or 24) * 3600) end

function Wheel.left(acc)
    return math.max(0, int(acc.wheelAt) + cooldown() - os.time())
end

local function kindOf(prize)
    if prize.premium then return 'premium' end
    if prize.weapon then return 'weapon' end
    if prize.case then return 'case' end
    if prize.xp then return 'xp' end
    return 'money'
end

function Wheel.view(acc)
    local prizes = {}
    for i, pr in ipairs(cfg().prizes or {}) do
        prizes[i] = { label = pr.label, color = pr.color, kind = kindOf(pr) }
    end
    return {
        enabled = cfg().enabled ~= false,
        prizes = prizes,
        left = Wheel.left(acc),
        total = cooldown(),
        last = acc.wheelLast,
    }
end

local function draw()
    local list = cfg().prizes or {}
    local total = 0
    for _, pr in ipairs(list) do total = total + math.max(0, pr.weight or 1) end
    local x = math.random() * total
    for i, pr in ipairs(list) do
        x = x - math.max(0, pr.weight or 1)
        if x < 0 then return i, pr end
    end
    return #list, list[#list]
end

-- Gewinn gutschreiben, liefert den Text für die Meldung
local function grant(p, pr)
    local acc = p.acc
    if pr.premium then
        if acc.premiumForever then
            local money = Config.Battlepass.duplicateMoney or 5000
            Accounts.addMoney(acc, money)
            return ('Premium hast du schon für immer – dafür +$%s'):format(Util.formatMoney(money))
        end
        Accounts.setPremium(acc, pr.premiumDays or 7)
        return ('Premium %s!'):format(Accounts.premiumText(acc))
    end
    if pr.weapon then
        local w = Weapons.get(pr.weapon)
        if w and not Accounts.owns(acc, w.name) then
            acc.weapons[#acc.weapons + 1] = w.name
            if not p.dead and (p.mode == 'ffa' or p.mode == 'gangwar' or p.mode == 'lobby') then
                TriggerClientEvent('bspvp:giveWeapon', p.src, w.name)
            end
            return ('%s gehört jetzt dir!'):format(w.label)
        end
        local money = Config.Battlepass.duplicateMoney or 5000
        Accounts.addMoney(acc, money)
        return ('Waffe schon im Besitz – dafür +$%s'):format(Util.formatMoney(money))
    end
    return Missions.grant(acc, p, { money = pr.money, xp = pr.xp, case = pr.case })
end

function Wheel.spin(p)
    if cfg().enabled == false then return Notify(p.src, 'error', 'Das Glücksrad ist ausgeschaltet.') end
    local acc = p.acc
    local left = Wheel.left(acc)
    if left > 0 then
        return Notify(p.src, 'error', ('Nächster Dreh in %d:%02d Std.'):format(left // 3600, (left % 3600) // 60))
    end
    if (p.wheelBusyUntil or 0) > Now() then return end
    p.wheelBusyUntil = Now() + 8000

    local index, pr = draw()
    if not pr then return end
    acc.wheelAt = os.time()
    local text = grant(p, pr)
    acc.wheelLast = pr.label
    Accounts.save(acc)
    Logs.add('wheel', ('%s hat **%s** gewonnen'):format(Logs.who(p), pr.label))

    TriggerClientEvent('bspvp:wheelResult', p.src, { index = index, label = pr.label, text = text, view = Wheel.view(acc) })
    -- Gutschrift erst nach der Animation zeigen
    SetTimeout(6500, function()
        if Players[p.src] ~= p then return end
        Accounts.push(p)
        Notify(p.src, 'success', ('Glücksrad: %s'):format(text))
        if (pr.weight or 1) <= 1 then
            Announce(-1, ('%s hat am Glücksrad %s gewonnen!'):format(acc.name, pr.label))
        end
    end)
end

RegisterNetEvent('bspvp:wheelSpin', function()
    local p = Guard(source)
    if p then Wheel.spin(p) end
end)

-- Hinweis nach dem Login, wenn gedreht werden kann
AddEventHandler('bspvp:loggedIn', function(src)
    local p = Players[src]
    if p and p.acc and cfg().enabled ~= false and Wheel.left(p.acc) <= 0 then
        SetTimeout(4000, function()
            if Players[src] == p then Notify(src, 'level', 'Das Glücksrad ist bereit – F2 → Glücksrad oder /gluecksrad') end
        end)
    end
end)
