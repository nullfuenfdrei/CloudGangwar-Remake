-- =======================================================================
--  Team-Ränge: Support < Moderator < Gangverwaltung < Teamverwaltung < Admin < Owner
--  Der höchste Rang aus diesen Quellen zählt:
--    - server.cfg (ACE): add_principal identifier.license:XYZ group.moderator
--    - Kennung in "set bodyshot_owners" / "set bodyshot_admins"
--    - im Spiel vergeben (F6 → Spieler → Rang), gespeichert am Account
--    - Discord-Rolle (Config.Staff.discordRoles, kommt vom Bot)
-- =======================================================================

Staff = { order = {}, byKey = {}, list = {} }

for i, r in ipairs(Config.Staff and Config.Staff.ranks or {}) do
    Staff.order[r.key] = i
    Staff.byKey[r.key] = r
    Staff.list[i] = r
end

local function level(key) return key and Staff.order[key] or 0 end
Staff.level = level

local function keyAt(n) return n > 0 and Staff.list[n] and Staff.list[n].key or nil end

local function listed(src, convar)
    local list = GetConvar(convar, '')
    if list == '' then return false end
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        for entry in list:gmatch('[^%s,;]+') do
            if entry == id then return true end
        end
    end
    return false
end

-- Rang eines Spielers (nil = kein Teammitglied). Konsole/Discord-Bot = Owner.
function Staff.rank(src)
    src = tonumber(src)
    if src == 0 then return 'owner' end
    if not src or not GetPlayerName(src) then return nil end
    local best = 0
    for key, i in pairs(Staff.order) do
        if i > best and IsPlayerAceAllowed(src, 'bodyshot.rank.' .. key) then best = i end
    end
    if IsPlayerAceAllowed(src, Config.AdminAce) or listed(src, 'bodyshot_admins') then best = math.max(best, level('admin')) end
    if listed(src, 'bodyshot_owners') then best = math.max(best, level('owner')) end
    local p = Players[src]
    if p and p.acc and p.acc.staffRank then best = math.max(best, level(p.acc.staffRank)) end
    if DiscordRoles and DiscordRoles.rankFor then best = math.max(best, level(DiscordRoles.rankFor(src))) end
    return keyAt(best)
end

-- Rang eines Accounts, auch offline (nur gespeicherter Rang)
function Staff.rankOfAccount(acc)
    if not acc then return nil end
    local p = PlayerByUserId(acc.id)
    if p then return Staff.rank(p.src) end
    return acc.staffRank
end

function Staff.need(action)
    return (Config.Staff and Config.Staff.actions and Config.Staff.actions[action]) or 'admin'
end

function Staff.can(src, action)
    return level(Staff.rank(src)) >= level(Staff.need(action))
end

function Staff.info(key)
    local r = key and Staff.byKey[key]
    return r and { key = r.key, label = r.label, color = r.color, level = level(r.key) } or nil
end

-- Für das Admin-Menü: eigener Rang + was man darf
function Staff.view(src)
    local key = Staff.rank(src)
    local can = {}
    for action in pairs(Config.Staff.actions or {}) do can[action] = Staff.can(src, action) end
    local ranks = {}
    for _, r in ipairs(Staff.list) do ranks[#ranks + 1] = { key = r.key, label = r.label, color = r.color, level = level(r.key) } end
    return { rank = Staff.info(key), level = level(key), can = can, ranks = ranks }
end

-- Rang im Spiel vergeben/wegnehmen (rankKey = '' -> keiner)
function Staff.setRank(src, acc, rankKey)
    rankKey = rankKey ~= '' and rankKey or nil
    if rankKey and not Staff.byKey[rankKey] then return false, 'Diesen Rang gibt es nicht.' end
    local mine = level(Staff.rank(src))
    local isOwner = mine >= level('owner')
    local current = level(Staff.rankOfAccount(acc))
    if not isOwner and (level(rankKey) >= mine or current >= mine) then
        return false, 'Du kannst nur Ränge unter deinem eigenen vergeben.'
    end
    acc.staffRank = rankKey
    Accounts.save(acc)
    local p = PlayerByUserId(acc.id)
    if p then
        TriggerClientEvent('bspvp:admin:flag', p.src, Staff.rank(p.src) ~= nil)
        Notify(p.src, rankKey and 'success' or 'info', rankKey and ('Du bist jetzt %s.'):format(Staff.byKey[rankKey].label) or 'Dein Team-Rang wurde entfernt.')
    end
    local label = rankKey and Staff.byKey[rankKey].label or 'kein Rang'
    return true, ('%s #%d: %s'):format(acc.name, acc.id, label)
end
