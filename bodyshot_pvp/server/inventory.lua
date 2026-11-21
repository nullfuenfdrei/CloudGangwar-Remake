-- =======================================================================
--  Inventar: Weste & Medkit, Waffen-Aufsätze (Premium), Kleiderschrank,
--  Einladungen (Ref-Code) und Spieler-Blips auf der Karte
--  Alles wird hier auf dem Server geprüft – der Client zeigt nur an.
-- =======================================================================

Items, Attachments, Wardrobe, Referral = {}, {}, {}, {}

local int = Util.int

-- -----------------------------------------------------------------------
--  Weste & Medkit
--  Start -> 3,5 s Balken beim Spieler -> Ende. Der Server misst die Zeit
--  selbst und bricht ab, wenn man dazwischen getroffen wurde.
-- -----------------------------------------------------------------------
local function itemCfg(kind)
    local c = Config.Items and Config.Items[kind]
    return type(c) == 'table' and c or nil
end

-- Unbegrenzt (Config.Items.unlimited): jeder hat immer welche, -1 = unendlich
local function unlimited() return Config.Items and Config.Items.unlimited == true end
function Items.count(acc, kind)
    if unlimited() then return -1 end
    return int(acc.items[kind])
end

function Items.view(acc)
    local out = {}
    for _, kind in ipairs({ 'vest', 'medkit' }) do
        local c = itemCfg(kind)
        if c then out[#out + 1] = { kind = kind, label = c.label, count = Items.count(acc, kind), price = c.price, max = c.max, key = c.key, unlimited = unlimited() } end
    end
    return out
end

RegisterNetEvent('bspvp:item:start', function(kind)
    local p = Guard(source)
    kind = tostring(kind)
    local c = itemCfg(kind)
    if not p or not c or p.dead then return end
    if p.mode ~= 'lobby' and p.mode ~= 'ffa' and p.mode ~= 'gangwar' and not (p.mode == 'duel' and Config.Items.allowInDuel) then
        return Notify(p.src, 'error', ('%s geht hier nicht.'):format(c.label))
    end
    if not unlimited() and Items.count(p.acc, kind) <= 0 then
        return Notify(p.src, 'error', ('Du hast keine %s mehr – kaufen unter F2 → Inventar.'):format(c.label))
    end
    if kind == 'vest' and p.armour >= Config.MaxArmour then return Notify(p.src, 'error', 'Deine Weste ist schon voll.') end
    if kind == 'medkit' and p.hp >= Config.MaxHealth then return Notify(p.src, 'error', 'Du hast schon volles Leben.') end
    p.using = { kind = kind, at = Now(), token = math.random(1, 999999999) }
    TriggerClientEvent('bspvp:item:started', p.src, { kind = kind, label = c.label, seconds = c.seconds, token = p.using.token })
end)

RegisterNetEvent('bspvp:item:cancel', function()
    local p = Players[source]
    if p then p.using = nil end
end)

RegisterNetEvent('bspvp:item:finish', function(token)
    local p = Players[source]
    if not p or not p.loggedIn or not p.using then return end
    local u = p.using
    p.using = nil
    local c = itemCfg(u.kind)
    if not c or u.token ~= token or p.dead then return end
    if Now() - u.at < c.seconds * 1000 - 400 then
        return AntiCheat.flag(p.src, 'itemSpeed', ('%s nach %d ms statt %d ms'):format(c.label, Now() - u.at, math.floor(c.seconds * 1000)), 'log')
    end
    if p.lastHit and p.lastHit.at > u.at then
        return Notify(p.src, 'error', ('%s abgebrochen – du wurdest getroffen.'):format(c.label))
    end
    if not unlimited() then
        if Items.count(p.acc, u.kind) <= 0 then return end
        p.acc.items[u.kind] = Items.count(p.acc, u.kind) - 1
    end
    if u.kind == 'vest' then
        p.armour = math.min(Config.MaxArmour, p.armour + (c.armour or Config.MaxArmour))
    else
        p.hp = math.min(Config.MaxHealth, p.hp + (c.health or Config.MaxHealth))
    end
    SendVitals(p)
    Accounts.save(p.acc)
    Accounts.push(p)
end)

RegisterNetEvent('bspvp:item:buy', function(kind, amount)
    local p = Guard(source)
    kind = tostring(kind)
    local c = itemCfg(kind)
    if not p or not c or unlimited() then return end
    amount = math.max(1, math.min(10, int(amount)))
    local have = Items.count(p.acc, kind)
    amount = math.min(amount, (c.max or 10) - have)
    if amount <= 0 then return Notify(p.src, 'error', ('Mehr als %d %s kannst du nicht tragen.'):format(c.max or 10, c.label)) end
    local cost = amount * (c.price or 0)
    if p.acc.money < cost then return Notify(p.src, 'error', ('Dir fehlen $%s.'):format(Util.formatMoney(cost - p.acc.money))) end
    Accounts.addMoney(p.acc, -cost)
    p.acc.items[kind] = have + amount
    Accounts.save(p.acc)
    Accounts.push(p)
    Notify(p.src, 'success', ('%dx %s gekauft (-$%s).'):format(amount, c.label, Util.formatMoney(cost)))
    Logs.add('shop', ('%s kauft %dx %s für $%s'):format(Logs.who(p), amount, c.label, Util.formatMoney(cost)))
    Progress.sendMenu(p)
end)

-- -----------------------------------------------------------------------
--  Waffen-Aufsätze (Premium)
-- -----------------------------------------------------------------------
-- Bauteil-Name für eine Waffe + Option ("_CLIP_02" -> COMPONENT_CARBINERIFLE_CLIP_02)
function Attachments.component(weapon, opt)
    if opt.component then return opt.component end
    if opt.suffix then return 'COMPONENT_' .. weapon:gsub('^WEAPON_', '') .. opt.suffix end
    return nil
end

function Attachments.slot(key)
    for _, s in ipairs(Config.Attachments and Config.Attachments.slots or {}) do
        if s.key == key then return s end
    end
    return nil
end

-- Alle denkbaren Aufsätze pro Waffe (der Client filtert, was die Waffe wirklich kann)
function Attachments.view(acc)
    local slots = {}
    for _, s in ipairs(Config.Attachments and Config.Attachments.slots or {}) do
        local opts = {}
        for _, o in ipairs(s.options or {}) do opts[#opts + 1] = { label = o.label, suffix = o.suffix, component = o.component } end
        slots[#slots + 1] = { key = s.key, label = s.label, options = opts }
    end
    return {
        slots = slots,
        equipped = acc.attachments,
        allowed = acc.premium or not (Config.Attachments and Config.Attachments.premiumOnly),
    }
end

RegisterNetEvent('bspvp:attach:set', function(weapon, slotKey, component)
    local p = Guard(source)
    if not p then return end
    weapon, slotKey = string.upper(tostring(weapon)), tostring(slotKey)
    component = component and string.upper(tostring(component)) or ''
    Accounts.syncPremium(p.acc)
    if Config.Attachments.premiumOnly and not p.acc.premium then
        return Notify(p.src, 'error', 'Aufsätze gibt es nur mit Premium.')
    end
    local w = Weapons.get(weapon)
    local slot = Attachments.slot(slotKey)
    if not w or not slot or not Accounts.owns(p.acc, w.name) then return end
    if component ~= '' then
        local ok = false
        for _, o in ipairs(slot.options or {}) do
            if Attachments.component(w.name, o) == component then ok = true break end
        end
        if not ok then return end
    end
    p.acc.attachments[w.name] = p.acc.attachments[w.name] or {}
    p.acc.attachments[w.name][slotKey] = component ~= '' and component or nil
    if next(p.acc.attachments[w.name]) == nil then p.acc.attachments[w.name] = nil end
    Accounts.save(p.acc)
    Accounts.push(p)
    TriggerClientEvent('bspvp:attachments', p.src, p.acc.attachments)
end)

-- -----------------------------------------------------------------------
--  Kleiderschrank (nur an der Hood). Oberteil bleibt in der Gangfarbe.
-- -----------------------------------------------------------------------
RegisterNetEvent('bspvp:outfit:save', function(data)
    local p = Guard(source)
    if not p or type(data) ~= 'table' then return end
    if p.mode ~= 'lobby' then return Notify(p.src, 'error', 'Umziehen geht nur an deiner Hood.') end
    local max = Config.Wardrobe.maxDrawable or 500
    local out = {}
    for _, s in ipairs(Config.Wardrobe.slots or {}) do
        local v = data[s.key]
        if type(v) == 'table' then
            if s.gang then
                out[s.key] = { v = math.max(1, math.min(10, int(v.v))) }               -- Variante der Gang-Kleidung
            else
                local d, t = int(v.d), int(v.t)
                if d >= -1 and d <= max and t >= 0 and t <= 64 then out[s.key] = { d = d, t = t } end
            end
        end
    end
    p.acc.outfit = out
    Accounts.save(p.acc)
    Accounts.push(p)
    Notify(p.src, 'success', 'Outfit gespeichert.')
end)

-- -----------------------------------------------------------------------
--  Einladungen: Ref-Code = User-ID des Einladers
-- -----------------------------------------------------------------------
local function refCfg() return Config.Referral or {} end

-- Belohnung gutschreiben (auch offline), liefert Text
local function grantReward(acc, r)
    if type(r) ~= 'table' then return '' end
    local p = PlayerByUserId(acc.id)
    local parts = { Missions.grant(acc, p, r) }
    if (r.premiumDays or 0) > 0 then
        Accounts.setPremium(acc, r.premiumDays)
        parts[#parts + 1] = ('%d Tage Premium'):format(r.premiumDays)
    end
    local text = table.concat(parts, ', '):gsub('^, ', '')
    return text
end

function Referral.link(p, acc, inviter)
    if not refCfg().enabled or inviter.id == acc.id then return end
    acc.refBy = inviter.id
    acc.refPaid = false
    local text = grantReward(acc, refCfg().newPlayer)
    Accounts.save(acc)
    Accounts.push(p)
    Notify(p.src, 'success', ('Eingeladen von %s – Willkommensgeschenk: %s'):format(inviter.name, text))
    local ip = PlayerByUserId(inviter.id)
    if ip then
        Notify(ip.src, 'info', ('%s hat sich mit deinem Code registriert. Deine Belohnung kommt nach %d Minuten Spielzeit.'):format(acc.name, refCfg().minutes or 60))
    end
    Logs.add('register', ('%s #%d wurde von %s #%d eingeladen'):format(acc.name, acc.id, inviter.name, inviter.id))
end

local function payInviter(acc)
    local inviter = Accounts.get(acc.refBy)
    acc.refPaid = true
    Accounts.save(acc)
    if not inviter then return end
    inviter.refs[#inviter.refs + 1] = acc.id
    local text = grantReward(inviter, refCfg().inviter)
    inviter.refEarned = int(inviter.refEarned) + int((refCfg().inviter or {}).money)
    -- Meilensteine
    inviter.refMilestones = type(inviter.refMilestones) == 'table' and inviter.refMilestones or {}
    local extra = {}
    for _, m in ipairs(refCfg().milestones or {}) do
        local key = tostring(m.count)
        if #inviter.refs >= m.count and not inviter.refMilestones[key] then
            inviter.refMilestones[key] = os.time()
            extra[#extra + 1] = ('%d Einladungen: %s'):format(m.count, grantReward(inviter, m.reward))
        end
    end
    Accounts.save(inviter)
    local ip = PlayerByUserId(inviter.id)
    if ip then
        Accounts.push(ip)
        Notify(ip.src, 'success', ('Einladung bestätigt (%s): %s'):format(acc.name, text))
        for _, e in ipairs(extra) do Notify(ip.src, 'level', 'Meilenstein! ' .. e) end
    end
    Logs.add('register', ('Einladung bestätigt: %s #%d -> %s #%d (%s)'):format(acc.name, acc.id, inviter.name, inviter.id, text))
end

CreateThread(function()
    while true do
        Wait(60000)
        local need = (refCfg().minutes or 60) * 60
        for _, p in pairs(Players) do
            local acc = p.loggedIn and p.acc
            if acc and acc.refBy and not acc.refPaid and int(acc.playSeconds) >= need then payInviter(acc) end
        end
    end
end)

function Referral.view(acc)
    local pending = 0
    for _, a in pairs(Accounts.byId) do
        if a.refBy == acc.id and not a.refPaid then pending = pending + 1 end
    end
    local milestones = {}
    for _, m in ipairs(refCfg().milestones or {}) do
        local parts = {}
        if (m.reward.money or 0) > 0 then parts[#parts + 1] = '$' .. Util.formatMoney(m.reward.money) end
        if m.reward.case and Skins.case(m.reward.case) then parts[#parts + 1] = Skins.case(m.reward.case).name end
        if (m.reward.premiumDays or 0) > 0 then parts[#parts + 1] = m.reward.premiumDays .. ' Tage Premium' end
        milestones[#milestones + 1] = { count = m.count, text = table.concat(parts, ' + '), reached = #acc.refs >= m.count }
    end
    local function rewardText(r)
        local parts = {}
        if (r.money or 0) > 0 then parts[#parts + 1] = '$' .. Util.formatMoney(r.money) end
        if (r.xp or 0) > 0 then parts[#parts + 1] = r.xp .. ' XP' end
        if r.case and Skins.case(r.case) then parts[#parts + 1] = Skins.case(r.case).name end
        return table.concat(parts, ' + ')
    end
    local by = acc.refBy and Accounts.get(acc.refBy)
    return {
        enabled = refCfg().enabled ~= false,
        code = acc.id,
        count = #acc.refs,
        pending = pending,
        earned = int(acc.refEarned),
        minutes = refCfg().minutes or 60,
        inviterReward = rewardText(refCfg().inviter or {}),
        newReward = rewardText(refCfg().newPlayer or {}),
        milestones = milestones,
        by = by and { id = by.id, name = by.name } or nil,
    }
end

-- -----------------------------------------------------------------------
--  Spieler auf der Karte: alle 30 s die Positionen an der Hood (Gangfarbe)
-- -----------------------------------------------------------------------
CreateThread(function()
    local cfg = Config.PlayerBlips or {}
    if cfg.enabled == false then return end
    while true do
        Wait(math.max(5, cfg.seconds or 30) * 1000)
        local list = {}
        for src, p in pairs(Players) do
            if p.loggedIn and p.mode == 'lobby' and not p.dead and p.team then
                local ped = GetPlayerPed(src)
                local info = Teams.info(p.team)
                if ped and ped ~= 0 and info then
                    local pos = GetEntityCoords(ped)
                    list[#list + 1] = { src = src, x = pos.x, y = pos.y, z = pos.z, blip = info.blip, team = info.name, key = info.key }
                end
            end
        end
        for src, p in pairs(Players) do
            if p.loggedIn and p.mode == 'lobby' then
                local myKey = Teams.key(p.team)
                local mine = {}
                for _, e in ipairs(list) do
                    if e.src ~= src and (cfg.showOwnTeam ~= false or e.key ~= myKey) then
                        mine[#mine + 1] = { sid = e.src, x = e.x, y = e.y, z = e.z, blip = e.blip, team = e.team }
                    end
                end
                TriggerClientEvent('bspvp:playerBlips', src, mine)
            elseif p.loggedIn then
                TriggerClientEvent('bspvp:playerBlips', src, {})
            end
        end
    end
end)
