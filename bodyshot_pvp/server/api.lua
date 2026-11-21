-- =======================================================================
--  Schnittstelle für den Discord-Bot
--  http://127.0.0.1:30120/bodyshot_pvp/api/...   (nur vom eigenen PC!)
--  Header "X-Api-Token" muss bodyshot_api_token aus der server.cfg sein.
--
--  GET  /api/status     Spieler online, Gebiete
--  GET  /api/accounts   alle Accounts mit verknüpftem Discord (Rollen-Sync)
--  POST /api/roles      { members = { [discordId] = { "Rolle", ... } } }
--  POST /api/action     { action, args, by } -> Admin-Aktion ausführen
-- =======================================================================

DiscordRoles = { byDiscord = {} }   -- [discordId] = { admin = bool, premium = bool }

local int = Util.int

local function roleMatch(names, list)
    for _, n in ipairs(names or {}) do
        n = tostring(n)
        for _, want in ipairs(list or {}) do
            if n == want or n:sub(-#want) == want then return true end
        end
    end
    return false
end

-- Höchster Team-Rang aus den Discord-Rollen (Config.Staff.discordRoles)
local function rankFromRoles(names)
    local best, bestLevel = nil, 0
    for key, list in pairs(Config.Staff and Config.Staff.discordRoles or {}) do
        local lvl = Staff.level(key)
        if lvl > bestLevel and roleMatch(names, list) then best, bestLevel = key, lvl end
    end
    return best
end

-- Server-Booster? (Rolle aus Config.DiscordRoles.booster, kommt vom Bot)
function DiscordRoles.isBooster(discordId)
    local r = discordId and DiscordRoles.byDiscord[tostring(discordId)]
    return r ~= nil and r.booster == true
end

function DiscordRoles.rankFor(src)
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        if id:sub(1, 8) == 'discord:' then
            local r = DiscordRoles.byDiscord[id:sub(9)]
            return r and r.rank or nil
        end
    end
    return nil
end

-- Rollen vom Bot übernehmen: Premium über Rolle, Team-Rang über Rolle
local function applyRoles(members)
    local seen = {}
    for discordId, names in pairs(members) do
        discordId = tostring(discordId)
        if discordId:match('^%d+$') and type(names) == 'table' then
            seen[discordId] = true
            DiscordRoles.byDiscord[discordId] = {
                rank = rankFromRoles(names),
                premium = roleMatch(names, Config.DiscordRoles and Config.DiscordRoles.premium),
                booster = roleMatch(names, Config.DiscordRoles and Config.DiscordRoles.booster),
            }
        end
    end
    for _, acc in pairs(Accounts.byId) do
        if acc.discord then
            local r = DiscordRoles.byDiscord[acc.discord]
            local want = r ~= nil and r.premium == true
            if acc.rolePremium ~= want then
                acc.rolePremium = want
                local changed = Accounts.syncPremium(acc)
                Accounts.save(acc)
                local p = PlayerByUserId(acc.id)
                if p and changed then
                    Accounts.push(p)
                    Notify(p.src, want and 'success' or 'info', want and 'Premium über deine Discord-Rolle aktiv!' or 'Premium über Discord-Rolle beendet.')
                end
            end
        end
    end
    -- Admin-Flag für Spieler online neu schicken
    for src, p in pairs(Players) do
        if p.loggedIn then TriggerClientEvent('bspvp:admin:flag', src, IsAdmin(src)) end
    end
end

local function playersView()
    local out = {}
    for src, p in pairs(Players) do
        if p.loggedIn and p.acc then
            local info = Teams.info(p.team)
            out[#out + 1] = {
                sid = src, id = p.acc.id, name = p.acc.name, discord = p.acc.discord,
                team = info and info.name or nil, tag = info and info.tag or nil,
                level = Accounts.level(p.acc), place = Progress.placeName(p),
                kills = p.acc.stats.kills, deaths = p.acc.stats.deaths,
                premium = p.acc.premium, admin = IsAdmin(src), ping = GetPlayerPing(src),
                rank = (Staff.info(Staff.rank(src)) or {}).label,
            }
        end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

local function accountsView()
    local out = {}
    for _, acc in pairs(Accounts.byId) do
        if acc.discord then
            local gang = acc.lastTeam and acc.lastTeam.kind == 'gang' and Util.gang(acc.lastTeam.id) or nil
            out[#out + 1] = {
                id = acc.id, name = acc.name, discord = acc.discord, level = Accounts.level(acc),
                gang = gang and gang.name or nil, gangColor = gang and gang.color or nil,
                -- nur echtes Premium aus dem Spiel (nicht das über die Rolle)
                premium = acc.premiumForever == true or int(acc.premiumUntil) > os.time(),
                online = PlayerByUserId(acc.id) ~= nil,
            }
        end
    end
    local gangs = {}
    for _, g in ipairs(Config.Gangs) do gangs[#gangs + 1] = { name = g.name, color = g.color } end
    return { accounts = out, gangs = gangs }
end

-- Admin-Aktionen, die der Bot auslösen darf
local BOT_ACTIONS = {
    kick = true, ban = true, unbanId = true, money = true, xp = true, premium = true, announce = true,
    heal = true, healAll = true, hood = true, endwar = true, case = true, mute = true, clearArena = true,
}

local function run(body)
    local action = tostring(body.action or '')
    if not BOT_ACTIONS[action] then return 400, { ok = false, message = 'Unbekannte Aktion.' } end
    local by = ('Discord: %s'):format(Util.trim(body.by or 'Bot'):sub(1, 40))
    local msg = Admin.runAs(by, action, type(body.args) == 'table' and body.args or {})
    return 200, { ok = msg ~= nil, message = msg or 'Keine Antwort.' }
end

local function reply(res, status, data)
    res.writeHead(status, { ['Content-Type'] = 'application/json; charset=utf-8' })
    res.send(json.encode(data))
end

SetHttpHandler(function(req, res)
    local path = tostring(req.path or ''):gsub('%?.*$', '')
    if path:sub(1, 5) ~= '/api/' then return reply(res, 404, { ok = false }) end

    -- nur vom eigenen PC und nur mit Token
    local addr = tostring(req.address or '')
    local fromLocal = addr:match('^127%.0%.0%.1') or addr:match('^%[?::1%]?') or addr:match('^localhost')
    local token = GetConvar('bodyshot_api_token', '')
    local sent = req.headers and (req.headers['X-Api-Token'] or req.headers['x-api-token']) or ''
    if not fromLocal or token == '' or #token < 16 or sent ~= token then
        return reply(res, 403, { ok = false, message = 'Kein Zugriff.' })
    end

    if req.method == 'GET' and path == '/api/status' then
        return reply(res, 200, {
            ok = true, online = OnlineCount(), max = GetConvarInt('sv_maxclients', 48),
            players = playersView(),
            server = ('%s %s'):format(Config.ServerName or '', Config.ServerTag or ''),
        })
    elseif req.method == 'GET' and path == '/api/accounts' then
        local v = accountsView()
        v.ok = true
        return reply(res, 200, v)
    elseif req.method == 'POST' then
        req.setDataHandler(function(raw)
            local ok, body = pcall(json.decode, raw or '')
            if not ok or type(body) ~= 'table' then return reply(res, 400, { ok = false, message = 'Ungültiges JSON.' }) end
            if path == '/api/roles' and type(body.members) == 'table' then
                applyRoles(body.members)
                return reply(res, 200, { ok = true })
            elseif path == '/api/action' then
                local status, data = run(body)
                return reply(res, status, data)
            end
            reply(res, 404, { ok = false })
        end)
        return
    end
    reply(res, 404, { ok = false })
end)
