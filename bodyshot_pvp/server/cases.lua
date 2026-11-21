-- =======================================================================
--  Cases & Waffen-Skins
--  Der Server zieht den Skin sofort und schreibt ihn gut. Der Client
--  bekommt danach die "Rolle" mit dem Gewinn an fester Stelle und spielt
--  nur noch die Animation ab.
-- =======================================================================

Cases = {}

local int = Util.int
local REEL = 46          -- Felder in der Rolle
local WIN_AT = 40        -- an dieser Stelle (1-basiert) bleibt die Rolle stehen

local function owns(acc, id)
    for _, s in ipairs(acc.skins) do
        if s == id then return true end
    end
    return false
end
Cases.owns = owns

-- Seltenheit nach Gewicht, dann gleichverteilt ein Skin dieser Seltenheit
function Cases.draw(caseKey)
    local c = Skins.case(caseKey)
    if not c then return nil end
    local byRarity = {}
    for _, s in ipairs(Skins.pool(caseKey)) do
        byRarity[s.rarity] = byRarity[s.rarity] or {}
        table.insert(byRarity[s.rarity], s)
    end
    local total = 0
    for key, w in pairs(c.weights or {}) do
        if byRarity[key] and w > 0 then total = total + w end
    end
    if total <= 0 then return nil end
    local x = math.random() * total
    local last
    for _, r in ipairs(Config.Rarities or {}) do
        local w = (c.weights or {})[r.key]
        local list = byRarity[r.key]
        if w and w > 0 and list then
            last = list
            if x < w then return list[math.random(#list)] end
            x = x - w
        end
    end
    return last and last[math.random(#last)] or nil
end

-- Chancen in Prozent (für die Anzeige)
function Cases.odds(caseKey)
    local c = Skins.case(caseKey)
    local present = {}
    for _, s in ipairs(Skins.pool(caseKey)) do present[s.rarity] = (present[s.rarity] or 0) + 1 end
    local total = 0
    for key, w in pairs(c and c.weights or {}) do
        if present[key] then total = total + w end
    end
    local out = {}
    for _, r in ipairs(Config.Rarities or {}) do
        local w = c and c.weights and c.weights[r.key]
        if w and w > 0 and present[r.key] then
            out[#out + 1] = { rarity = r.key, name = r.name, color = r.color, percent = math.floor(w / total * 1000 + 0.5) / 10, count = present[r.key] }
        end
    end
    return out
end

function Cases.open(p, caseKey)
    local acc = p.acc
    local c = Skins.case(tostring(caseKey))
    if not c then return Notify(p.src, 'error', 'Diese Case gibt es nicht.') end
    if p.caseBusyUntil and Now() < p.caseBusyUntil then return Notify(p.src, 'error', 'Warte, bis die Case fertig ist.') end

    local owned = int(acc.cases[c.key])
    local paid = 0
    if owned > 0 then
        acc.cases[c.key] = owned - 1
        if acc.cases[c.key] <= 0 then acc.cases[c.key] = nil end
    elseif (c.price or 0) > 0 then
        if acc.money < c.price then
            return Notify(p.src, 'error', ('Dir fehlen $%s.'):format(Util.formatMoney(c.price - acc.money)))
        end
        Accounts.addMoney(acc, -c.price)
        paid = c.price
    else
        return Notify(p.src, 'error', ('Die %s gibt es nur als Belohnung (Login-Bonus, Battlepass).'):format(c.name))
    end

    local skin = Cases.draw(c.key)
    if not skin then
        -- Case ist leer konfiguriert: zurückgeben
        if paid > 0 then Accounts.addMoney(acc, paid) else acc.cases[c.key] = int(acc.cases[c.key]) + 1 end
        return Notify(p.src, 'error', 'In dieser Case ist gerade nichts drin.')
    end

    local duplicate = owns(acc, skin.id)
    local refund = 0
    if duplicate then
        refund = (Skins.rarity[skin.rarity] or {}).duplicate or 0
        Accounts.addMoney(acc, refund)
    else
        acc.skins[#acc.skins + 1] = skin.id
    end
    acc.stats.casesOpened = int(acc.stats.casesOpened) + 1
    Missions.track(acc, 'caseOpen', 1, p)
    Accounts.save(acc)
    DB.log('case', { account_id = acc.id, case_key = c.key, skin_key = skin.id, rarity = skin.rarity, duplicate = duplicate })
    Logs.add('case', ('%s öffnet %s: **%s**'):format(Logs.who(p), c.name, tostring(skin.name or skin.id)), {
        { 'Seltenheit', tostring((Skins.rarity[skin.rarity] or {}).name or skin.rarity), true },
        { 'Doppelt', duplicate and 'Ja' or 'Nein', true },
    })

    -- Rolle bauen: Zufallsfelder, Gewinn an fester Stelle
    local reel = {}
    for i = 1, REEL do
        local s = (i == WIN_AT) and skin or Cases.draw(c.key)
        reel[i] = Skins.view(s)
    end
    p.caseBusyUntil = Now() + 6500
    TriggerClientEvent('bspvp:caseResult', p.src, {
        case = c.key, caseName = c.name, color = c.color,
        reel = reel, win = WIN_AT, skin = Skins.view(skin), duplicate = duplicate, refund = refund,
    })

    -- Erst nach der Animation allen sagen, was es war (nicht spoilern)
    if skin.rarity == 'legendary' or skin.rarity == 'epic' then
        local name, label = acc.name, ('%s | %s'):format(skin.weaponLabel, skin.name)
        local rname = (Skins.rarity[skin.rarity] or {}).name or skin.rarity
        SetTimeout(6500, function()
            Chat(-1, ('^3%s^7 hat ^5%s^7 (%s) aus der %s gezogen!'):format(name, label, rname, c.name))
        end)
    end
    SetTimeout(6500, function()
        local q = PlayerByUserId(acc.id)
        if q then Accounts.push(q) end
    end)
end

-- -----------------------------------------------------------------------
--  Ausrüsten
-- -----------------------------------------------------------------------
-- Was der Client zum Lackieren braucht: { [Waffe] = { id, tint, component } }
function Cases.loadoutSkins(acc)
    local out = {}
    for weapon, id in pairs(acc.equipped or {}) do
        local s = Skins.get(id)
        if s and s.weapon == weapon then
            out[weapon] = { id = s.id, tint = s.tint, component = s.component }
        end
    end
    return out
end

function Cases.pushSkins(p)
    if p and p.acc then
        TriggerClientEvent('bspvp:skins', p.src, Cases.loadoutSkins(p.acc))
    end
end

function Cases.equip(p, id)
    local s = Skins.get(id)
    if not s or not owns(p.acc, s.id) then return Notify(p.src, 'error', 'Diesen Skin hast du nicht.') end
    p.acc.equipped[s.weapon] = s.id
    Accounts.save(p.acc)
    Cases.pushSkins(p)
    Notify(p.src, 'success', ('%s | %s ausgerüstet.'):format(s.weaponLabel, s.name))
end

function Cases.unequip(p, weapon)
    weapon = Weapons.get(weapon) and Weapons.get(weapon).name or nil
    if not weapon or not p.acc.equipped[weapon] then return end
    p.acc.equipped[weapon] = nil
    Accounts.save(p.acc)
    Cases.pushSkins(p)
    Notify(p.src, 'info', ('%s: Standard-Lackierung.'):format(Weapons.get(weapon).label))
end

-- -----------------------------------------------------------------------
--  Menü
-- -----------------------------------------------------------------------
function Cases.view(acc)
    local cases = {}
    for _, c in ipairs(Config.Cases or {}) do
        local pool = Skins.pool(c.key)
        table.sort(pool, function(a, b)
            local ra, rb = (Skins.rarity[a.rarity] or {}).order or 0, (Skins.rarity[b.rarity] or {}).order or 0
            if ra ~= rb then return ra > rb end
            return a.id < b.id
        end)
        local preview = {}
        for i = 1, math.min(8, #pool) do preview[i] = Skins.view(pool[i]) end
        cases[#cases + 1] = {
            key = c.key, name = c.name, price = c.price or 0, color = c.color,
            owned = int(acc.cases[c.key]), odds = Cases.odds(c.key), count = #pool, preview = preview,
        }
    end
    local skins = {}
    for _, id in ipairs(acc.skins) do
        local s = Skins.get(id)
        if s then
            local v = Skins.view(s)
            v.equipped = acc.equipped[s.weapon] == s.id
            v.ownsWeapon = Accounts.owns(acc, s.weapon)
            skins[#skins + 1] = v
        end
    end
    table.sort(skins, function(a, b)
        local ra, rb = (Skins.rarity[a.rarity] or {}).order or 0, (Skins.rarity[b.rarity] or {}).order or 0
        if ra ~= rb then return ra > rb end
        return a.id < b.id
    end)
    local total = 0
    for _ in pairs(Skins.byId) do total = total + 1 end
    return { cases = cases, skins = skins, total = total, rarities = Config.Rarities }
end

-- -----------------------------------------------------------------------
--  Client -> Server
-- -----------------------------------------------------------------------
RegisterNetEvent('bspvp:caseOpen', function(key)
    local p = Guard(source)
    if not p then return end
    Cases.open(p, key)
end)

RegisterNetEvent('bspvp:skinEquip', function(id)
    local p = Guard(source)
    if not p then return end
    Cases.equip(p, tostring(id))
    Progress.sendMenu(p)
end)

RegisterNetEvent('bspvp:skinUnequip', function(weapon)
    local p = Guard(source)
    if not p then return end
    Cases.unequip(p, tostring(weapon))
    Progress.sendMenu(p)
end)
