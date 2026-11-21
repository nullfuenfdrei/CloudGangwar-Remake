-- =======================================================================
--  Accounts & Login
--  - Erkennung über die Rockstar-Lizenz (license:...)
--  - User-IDs fortlaufend ab 0
-- =======================================================================

Accounts = { byId = {} }

local int = Util.int

function Accounts.owns(acc, name)
    for _, n in ipairs(acc.weapons) do
        if n == name then return true end
    end
    return false
end

-- fehlende Felder ergänzen, Zahlen aus JSON glätten
function Accounts.normalize(acc)
    acc.id = int(acc.id)
    acc.money = int(acc.money or Config.Accounts.startMoney)
    acc.xp = int(acc.xp)
    acc.weapons = acc.weapons or {}
    acc.claimed = acc.claimed or {}
    acc.claimed.free = acc.claimed.free or {}
    acc.claimed.premium = acc.claimed.premium or {}
    for _, track in ipairs({ 'free', 'premium' }) do
        for i, lvl in ipairs(acc.claimed[track]) do acc.claimed[track][i] = int(lvl) end
    end
    acc.stats = acc.stats or {}
    for _, k in ipairs({ 'kills', 'deaths', 'best', 'gwWins', 'gwPlayed', 'duelWins', 'duelLosses',
                         'bounties', 'bountyEarned', 'bountyPlaced', 'casesOpened' }) do
        acc.stats[k] = int(acc.stats[k])
    end
    -- Skins & Cases (v4)
    acc.skins = type(acc.skins) == 'table' and acc.skins or {}
    for i = #acc.skins, 1, -1 do
        if not Skins.get(acc.skins[i]) then table.remove(acc.skins, i) end   -- Skin gibt es nicht mehr
    end
    acc.equipped = type(acc.equipped) == 'table' and acc.equipped or {}
    for weapon, id in pairs(acc.equipped) do
        local s = Skins.get(id)
        local owned = false
        for _, x in ipairs(acc.skins) do if x == id then owned = true break end end
        if not s or s.weapon ~= weapon or not owned then acc.equipped[weapon] = nil end
    end
    acc.cases = type(acc.cases) == 'table' and acc.cases or {}
    for key, n in pairs(acc.cases) do
        acc.cases[key] = int(n)
        if acc.cases[key] <= 0 or not Skins.case(key) then acc.cases[key] = nil end
    end
    -- Premium: für immer, auf Zeit (premiumUntil) oder über eine Discord-Rolle
    if acc.premiumForever == nil then acc.premiumForever = acc.premium == true and int(acc.premiumUntil) == 0 end
    acc.premiumUntil = int(acc.premiumUntil)
    acc.rolePremium = acc.rolePremium == true
    acc.premium = acc.premiumForever or acc.premiumUntil > os.time() or acc.rolePremium
    -- Inventar: Westen & Medkits, Waffen-Aufsätze, Kleidung, Einladungen
    acc.items = type(acc.items) == 'table' and acc.items or {}
    for key in pairs(acc.items) do
        if not (Config.Items and type(Config.Items[key]) == 'table') then acc.items[key] = nil else acc.items[key] = math.max(0, int(acc.items[key])) end
    end
    acc.attachments = type(acc.attachments) == 'table' and acc.attachments or {}
    acc.outfit = type(acc.outfit) == 'table' and acc.outfit or {}
    acc.refs = type(acc.refs) == 'table' and acc.refs or {}
    acc.playSeconds = int(acc.playSeconds)
    acc.mutedUntil = int(acc.mutedUntil)
    if acc.privateTeam ~= nil then acc.privateTeam = int(acc.privateTeam) end
    if acc.lastTeam and acc.lastTeam.kind == 'private' then acc.lastTeam.id = int(acc.lastTeam.id) end

    -- neue Battlepass-Season -> Fortschritt zurücksetzen
    if int(acc.season) ~= int(Config.Battlepass.season) then
        acc.season = int(Config.Battlepass.season)
        acc.xp = 0
        acc.claimed = { free = {}, premium = {} }
    end

    -- Startwaffen (Preis 0) hat jeder
    for _, w in ipairs(Weapons.list) do
        if w.price == 0 and not Accounts.owns(acc, w.name) then
            acc.weapons[#acc.weapons + 1] = w.name
        end
    end
    -- Waffen, die es nicht mehr gibt, entfernen
    for i = #acc.weapons, 1, -1 do
        if not Weapons.get(acc.weapons[i]) then table.remove(acc.weapons, i) end
    end
    return acc
end

function Accounts.loadAll()
    for _, key in ipairs(DB.keys('acc:')) do
        local acc = DB.get(key)
        if type(acc) == 'table' and acc.id ~= nil then
            acc = Accounts.normalize(acc)
            Accounts.byId[acc.id] = acc
        end
    end
end

function Accounts.save(acc)
    DB.saveAccount(acc)
end

function Accounts.get(id)
    id = int(id)
    local acc = Accounts.byId[id]
    if acc then return acc end
    acc = DB.loadAccount(id)
    if acc then
        acc = Accounts.normalize(acc)
        Accounts.byId[acc.id] = acc
    end
    return acc
end

function Accounts.byLicense(license)
    if not license then return nil end
    local id = DB.accountIdByLicense(license)
    if id == nil then return nil end
    return Accounts.get(id)
end

function Accounts.validateName(name)
    if type(name) ~= 'string' then return nil, 'Ungültiger Name.' end
    name = name:match('^%s*(.-)%s*$')
    local min, max = Config.Accounts.nameMin, Config.Accounts.nameMax
    if #name < min or #name > max then
        return nil, ('Der Name muss %d bis %d Zeichen lang sein.'):format(min, max)
    end
    if not name:match('^[%w_]+$') then
        return nil, 'Nur Buchstaben (ohne Umlaute), Zahlen und _ erlaubt.'
    end
    if DB.accountIdByName(name) ~= nil then
        return nil, 'Dieser Name ist schon vergeben.'
    end
    return name
end

function Accounts.create(license, name)
    local id = DB.nextId('user')          -- 0, 1, 2, ...
    local acc = Accounts.normalize({
        id = id,
        license = license,
        name = name,
        created = os.time(),
        season = Config.Battlepass.season,
        money = Config.Accounts.startMoney,
        premiumForever = false,
    })
    -- Premium zum Testen + Start-Westen/Medkits
    local trial = Config.Premium and Config.Premium.trialDays or 0
    if trial > 0 then Accounts.setPremium(acc, trial) end
    for key, item in pairs(Config.Items or {}) do
        if type(item) == 'table' then acc.items[key] = Config.Items.startAmount or 0 end
    end
    Accounts.byId[acc.id] = acc
    DB.saveAccount(acc)
    DB.linkLicense(license, acc.id)
    DB.linkName(name, acc.id)
    return acc
end

function Accounts.level(acc)
    return Util.levelFromXp(acc.xp)
end

-- -----------------------------------------------------------------------
--  Premium
-- -----------------------------------------------------------------------
-- acc.premium immer aktuell halten (läuft ab, Discord-Rolle kommt/geht)
function Accounts.syncPremium(acc)
    local before = acc.premium
    acc.premium = acc.premiumForever == true or int(acc.premiumUntil) > os.time() or acc.rolePremium == true
    return before ~= acc.premium
end

-- days > 0: verlängern, 0: für immer, < 0: wegnehmen
function Accounts.setPremium(acc, days)
    days = tonumber(days) or 0
    if days < 0 then
        acc.premiumForever, acc.premiumUntil = false, 0
    elseif days == 0 then
        acc.premiumForever = true
    else
        acc.premiumUntil = math.max(os.time(), int(acc.premiumUntil)) + math.floor(days * 86400)
    end
    Accounts.syncPremium(acc)
end

function Accounts.premiumText(acc)
    if acc.premiumForever then return 'für immer' end
    local left = int(acc.premiumUntil) - os.time()
    if left > 0 then
        if left >= 86400 then return ('noch %d Tage'):format(math.ceil(left / 86400)) end
        return ('noch %d Std'):format(math.ceil(left / 3600))
    end
    if acc.rolePremium then return 'über Discord-Rolle' end
    return 'aus'
end

-- Jede Minute: abgelaufenes Premium beenden
CreateThread(function()
    while true do
        Wait(60000)
        for _, p in pairs(Players) do
            if p.loggedIn and p.acc and Accounts.syncPremium(p.acc) then
                Accounts.save(p.acc)
                Accounts.push(p)
                Notify(p.src, p.acc.premium and 'success' or 'info', p.acc.premium and 'Premium ist jetzt aktiv!' or 'Dein Premium ist abgelaufen.')
            end
        end
    end
end)

function Accounts.addMoney(acc, amount)
    acc.money = math.max(0, acc.money + int(amount))
end

function Accounts.addXp(p, amount)
    local acc = p.acc
    local before = Accounts.level(acc)
    acc.xp = math.max(0, (acc.xp or 0) + int(amount))   -- nie negativ (Admin-Abzug)
    local after = Accounts.level(acc)
    if after > before then
        Notify(p.src, 'level', ('Battlepass Level %d erreicht! Belohnung im Menü abholen.'):format(after))
    end
end

function Accounts.view(acc)
    Accounts.syncPremium(acc)
    return {
        premiumText = Accounts.premiumText(acc),
        premiumUntil = acc.premiumUntil,
        items = acc.items,
        attachments = acc.attachments,
        outfit = acc.outfit,
        discord = acc.discordProfile,
        booster = acc.discord ~= nil and DiscordRoles ~= nil and DiscordRoles.isBooster(acc.discord),
        staffRank = (function()
            local p = PlayerByUserId(acc.id)
            return p and Staff.info(Staff.rank(p.src)) or nil
        end)(),
        refCount = #acc.refs,
        id = acc.id,
        name = acc.name,
        money = acc.money,
        xp = acc.xp,
        level = Accounts.level(acc),
        progress = Util.levelProgress(acc.xp),
        maxLevel = Util.maxLevel(),
        xpPerLevel = Config.Battlepass.xpPerLevel,
        premium = acc.premium,
        weapons = acc.weapons,
        stats = acc.stats,
        created = acc.created,
        playMinutes = math.floor((acc.playSeconds or 0) / 60),
        skins = #acc.skins,
        cases = (function() local n = 0 for _, c in pairs(acc.cases) do n = n + c end return n end)(),
        daily = Missions.pending(acc),
        bounty = Bounty.amount(acc.id),
    }
end

function Accounts.push(p)
    if p and p.acc then
        TriggerClientEvent('bspvp:account', p.src, Accounts.view(p.acc))
    end
end

function Accounts.top(limit)
    local list = {}
    for _, acc in pairs(Accounts.byId) do list[#list + 1] = acc end
    table.sort(list, function(a, b)
        if a.stats.kills ~= b.stats.kills then return a.stats.kills > b.stats.kills end
        return a.id < b.id
    end)
    local out = {}
    for i = 1, math.min(limit or 10, #list) do
        local a = list[i]
        out[#out + 1] = {
            id = a.id,
            name = a.name,
            kills = a.stats.kills,
            deaths = a.stats.deaths,
            kd = a.stats.deaths > 0 and math.floor(a.stats.kills / a.stats.deaths * 100 + 0.5) / 100 or a.stats.kills,
            level = Accounts.level(a),
            gwWins = a.stats.gwWins,
        }
    end
    return out
end

-- -----------------------------------------------------------------------
--  Login-Ablauf (Modus-Auswahl)
-- -----------------------------------------------------------------------
local function sanitizeName(name)
    name = tostring(name or ''):gsub('[^%w_]', '')
    return name:sub(1, Config.Accounts.nameMax)
end

local function loginError(p, msg)
    TriggerClientEvent('bspvp:loginError', p.src, msg)
end

function Accounts.loginPayload(p)
    local acc = Accounts.byLicense(p.license)
    local notice
    if Config.Connect and Config.Connect.title then
        local first = Config.Connect.text and Config.Connect.text[1]
        notice = { title = Config.Connect.title, text = first and first.text or '' }
    end
    return {
        registered = acc ~= nil,
        account = acc and Accounts.view(acc) or nil,
        suggestedName = sanitizeName(GetPlayerName(p.src)),
        serverName = Config.ServerName,
        serverTag = Config.ServerTag,
        nameMin = Config.Accounts.nameMin,
        nameMax = Config.Accounts.nameMax,
        noLicense = p.license == nil,
        modes = { { key = 'bodyshot', name = 'Bodyshot', online = OnlineCount() } },
        notice = notice,
    }
end

local function welcome(p)
    TriggerClientEvent('bspvp:chat', p.src, { kind = 'system', text = ('Willkommen auf %s %s'):format(Config.ServerName, Config.ServerTag or '') })
    for _, line in ipairs(Config.Chat and Config.Chat.welcome or {}) do
        TriggerClientEvent('bspvp:chat', p.src, { kind = 'plain', text = line })
    end
end

local function completeLogin(p, acc)
    local other = PlayerByUserId(acc.id)
    if other and other ~= p then
        loginError(p, 'Dieser Account ist schon online.')
        return
    end
    p.acc = acc
    p.loggedIn = true
    p.streak = 0
    for _, id in ipairs(GetPlayerIdentifiers(p.src) or {}) do
        if id:sub(1, 8) == 'discord:' then acc.discord = id:sub(9) end    -- für den Discord-Rollen-Sync
    end
    p.playNext = Now() + math.max(1, Config.PlaytimeReward and Config.PlaytimeReward.minutes or 60) * 60000
    acc.lastLogin = os.time()
    Missions.ensure(acc)
    local dailyReady = Missions.login(acc)
    Accounts.save(acc)
    TriggerClientEvent('bspvp:loginOk', p.src, Accounts.view(acc))
    Accounts.push(p)
    welcome(p)
    Accounts.pushHud(p)
    TriggerEvent('bspvp:loggedIn', p.src)
    TriggerClientEvent('bspvp:hoods', p.src, Hoods.mapView())
    Cases.pushSkins(p)
    Bounty.syncState(acc.id)
    if dailyReady then
        Notify(p.src, 'level', ('Tagesbonus bereit (Tag %d der Serie) – F2 → Täglich'):format(acc.login.streak))
    end

    -- Nach jedem Login wird das Team neu gewählt (das letzte ist vorausgewählt)
    Teams.openSelect(p)
    Accounts.fetchAvatar(p)
    Logs.add('join', ('%s ist online'):format(Logs.who(p)), {
        { 'Level', tostring(Accounts.level(acc)), true }, { 'Geld', '$' .. Util.formatMoney(acc.money), true },
        { 'Kennungen', Logs.ids(p.src) },
    })
    Chat(-1, ('^7%s ^5#%d^7 ist online.'):format(acc.name, acc.id))
end

-- -----------------------------------------------------------------------
--  Discord-Profilbild für den Todesbildschirm (optional, braucht Bot-Token)
-- -----------------------------------------------------------------------
function Accounts.fetchAvatar(p)
    if not (Config.DeathScreen and Config.DeathScreen.discordAvatars) then return end
    local token = GetConvar('bodyshot_discordToken', '')
    if token == '' then return end
    local discordId
    for _, id in ipairs(GetPlayerIdentifiers(p.src) or {}) do
        if id:sub(1, 8) == 'discord:' then discordId = id:sub(9) break end
    end
    if not discordId or not discordId:match('^%d+$') then return end
    PerformHttpRequest('https://discord.com/api/v10/users/' .. discordId, function(status, body)
        if status ~= 200 or not body or Players[p.src] ~= p then return end
        local ok, user = pcall(json.decode, body)
        if not ok or type(user) ~= 'table' then return end
        -- Name + Bild fürs F2-Profil (und den Todesbildschirm)
        local name = type(user.global_name) == 'string' and user.global_name or (type(user.username) == 'string' and user.username) or nil
        if type(user.avatar) == 'string' and user.avatar:match('^[%w_]+$') then
            local ext = user.avatar:sub(1, 2) == 'a_' and 'gif' or 'png'
            p.avatar = ('https://cdn.discordapp.com/avatars/%s/%s.%s?size=128'):format(discordId, user.avatar, ext)
        else
            p.avatar = ('https://cdn.discordapp.com/embed/avatars/%d.png'):format((tonumber(discordId:sub(-3)) or 0) % 6)
        end
        -- Profil-Banner (Nitro) und Profilfarbe – Booster zeigen das im Spiel
        local banner
        if type(user.banner) == 'string' and user.banner:match('^[%w_]+$') then
            local ext = user.banner:sub(1, 2) == 'a_' and 'gif' or 'png'
            banner = ('https://cdn.discordapp.com/banners/%s/%s.%s?size=600'):format(discordId, user.banner, ext)
        end
        local accent = tonumber(user.accent_color) and ('#%06x'):format(math.floor(tonumber(user.accent_color)) % 0x1000000) or nil
        if p.acc then
            p.acc.discordProfile = {
                id = discordId, avatar = p.avatar, banner = banner, accent = accent,
                name = name and name:sub(1, 40) or nil,
                username = type(user.username) == 'string' and user.username:sub(1, 40) or nil,
            }
            Accounts.save(p.acc)
            Accounts.push(p)
        end
    end, 'GET', '', { ['Authorization'] = 'Bot ' .. token })
end

RegisterNetEvent('bspvp:ready', function()
    local src = source
    if not DB.ready and not DB.waitReady(60000) then return end
    local p = Players[src]
    if not p then
        p = NewPlayerState(src)
        Players[src] = p
    end
    if p.loggedIn then
        -- Client-Skript neu gestartet: einfach den aktuellen Modus erneut schicken
        Accounts.push(p)
        Accounts.pushHud(p)
        TriggerClientEvent('bspvp:hoods', p.src, Hoods.mapView())
        TriggerClientEvent('bspvp:admin:flag', p.src, IsAdmin(p.src))
        Cases.pushSkins(p)
        Modes.resend(p)
        return
    end

    SetPlayerRoutingBucket(src, 5000 + src)    -- eigene Welt bis zum Login
    TriggerClientEvent('bspvp:loginScreen', src, Accounts.loginPayload(p))
end)

RegisterNetEvent('bspvp:register', function(name, refCode)
    local p = Players[source]
    if not p or p.loggedIn then return end
    if not p.license then
        loginError(p, 'Keine Rockstar-Lizenz gefunden. Starte FiveM neu.')
        return
    end
    if Accounts.byLicense(p.license) then
        loginError(p, 'Du hast schon einen Account – einfach einloggen.')
        return
    end
    local clean, err = Accounts.validateName(name)
    if not clean then
        loginError(p, err)
        return
    end
    -- Einladungscode prüfen, BEVOR der Account angelegt wird
    local inviter
    local code = tostring(refCode or ''):gsub('[^%d]', '')
    if code ~= '' and Config.Referral and Config.Referral.enabled then
        inviter = Accounts.get(tonumber(code))
        if not inviter then
            loginError(p, ('Den Einladungscode %s gibt es nicht. Feld leer lassen oder richtige User-ID eingeben.'):format(code))
            return
        end
    end
    local acc = Accounts.create(p.license, clean)
    Logs.add('register', ('Neuer Account: **%s #%d**'):format(acc.name, acc.id), {
        { 'Eingeladen von', inviter and ('%s #%d'):format(inviter.name, inviter.id) or '–', true },
        { 'Kennungen', Logs.ids(p.src) },
    })
    completeLogin(p, acc)
    if inviter then Referral.link(p, acc, inviter) end
end)

RegisterNetEvent('bspvp:login', function()
    local p = Players[source]
    if not p or p.loggedIn then return end
    local acc = Accounts.byLicense(p.license)
    if not acc then
        loginError(p, 'Kein Account gefunden – bitte registrieren.')
        return
    end
    completeLogin(p, acc)
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    local p = Players[src]
    if not p then return end
    if p.acc then
        Logs.add('leave', ('%s ist offline'):format(Logs.who(p)), {
            { 'Grund', tostring(reason or '–') },
            { 'Spielzeit gesamt', ('%d Std'):format(math.floor((p.acc.playSeconds or 0) / 3600)), true },
        })
    end
    if p.mode == 'gangwar' then Gangwar.removePlayer(p) end
    if p.duelId then Duels.leave(p, 'disconnect') end
    Duels.dropInvites(p)
    Garage.cleanup(p)
    if p.acc then Accounts.save(p.acc) end
    Players[src] = nil
end)

-- -----------------------------------------------------------------------
--  HUD-Daten: Spieler online + Spielzeit-Bonus
-- -----------------------------------------------------------------------
function Accounts.pushHud(p)
    local r = Config.PlaytimeReward or {}
    TriggerClientEvent('bspvp:hud', p.src, {
        online = OnlineCount(),
        reward = (r.minutes or 0) > 0 and {
            seconds = math.max(0, math.ceil((p.playNext - Now()) / 1000)),
            total = (r.minutes or 60) * 60,
            money = r.money or 0,
        } or nil,
    })
end

CreateThread(function()
    local tick = 0
    while true do
        Wait(5000)
        tick = tick + 1
        local r = Config.PlaytimeReward or {}
        local t = Now()
        for _, p in pairs(Players) do
            if p.loggedIn and p.acc then
                p.acc.playSeconds = (p.acc.playSeconds or 0) + 5
                p.minuteAcc = (p.minuteAcc or 0) + 5
                if p.minuteAcc >= 60 then
                    p.minuteAcc = p.minuteAcc - 60
                    Missions.track(p.acc, 'minutes', 1, p)
                end
                if (r.minutes or 0) > 0 and t >= p.playNext then
                    p.playNext = t + r.minutes * 60000
                    Accounts.addMoney(p.acc, r.money or 0)
                    if (r.xp or 0) > 0 then Accounts.addXp(p, r.xp) end
                    Accounts.save(p.acc)
                    Accounts.push(p)
                    Notify(p.src, 'success', ('Spielzeit-Bonus: +$%s'):format(Util.formatMoney(r.money or 0)))
                    Accounts.pushHud(p)
                elseif tick % 3 == 0 then
                    Accounts.pushHud(p)
                end
            end
        end
    end
end)
