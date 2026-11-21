-- =======================================================================
--  Speicher: MySQL (oxmysql) oder Resource-KVP
--
--  Config.Database.mode
--    'auto'  = MySQL, wenn oxmysql läuft – sonst KVP (Standard)
--    'mysql' = immer MySQL (Server wartet, bis die Datenbank erreichbar ist)
--    'kvp'   = keine Datenbank, alles in der Resource-KVP wie in v3
--
--  MySQL-Modus: Beim Start wird alles einmal geladen (die Datenmenge ist
--  klein). Lesen geht danach aus dem Speicher, Schreiben landet gesammelt
--  einmal pro Sekunde in einer Transaktion in der Datenbank. Dadurch bleibt
--  die Reihenfolge immer richtig und die Datenbank wird nicht zugespammt.
--
--  Erster Start mit leerer Datenbank: vorhandene KVP-Daten (v3) werden
--  automatisch übernommen. Die KVP bleibt als Sicherung liegen.
-- =======================================================================

DB = { mode = 'kvp', ready = false, status = 'Startet …', failures = 0, lastFlush = 0, migrated = false }

local PREFIX = 'gw:'
local int = Util.int
local FLUSH_MS = 1000

local function cfg() return Config.Database or {} end
local function log(msg) print('^5[bodyshot_pvp]^7 ' .. msg) end
local function warn(msg) print('^1[bodyshot_pvp] ' .. msg .. '^7') end

-- -----------------------------------------------------------------------
--  KVP (wie v3)
-- -----------------------------------------------------------------------
local Kvp = {}

function Kvp.raw(key) return GetResourceKvpString(PREFIX .. key) end

function Kvp.get(key)
    local raw = Kvp.raw(key)
    if not raw or raw == '' then return nil end
    local ok, value = pcall(json.decode, raw)
    if ok then return value end
    return nil
end

function Kvp.set(key, value)
    if value == nil then
        DeleteResourceKvp(PREFIX .. key)
    else
        SetResourceKvp(PREFIX .. key, json.encode(value))
    end
end

function Kvp.keys(prefix)
    local out = {}
    local handle = StartFindKvp(PREFIX .. prefix)
    if not handle or handle == -1 then return out end
    while true do
        local key = FindKvp(handle)
        if not key then break end
        out[#out + 1] = string.sub(key, #PREFIX + 1)
    end
    EndFindKvp(handle)
    return out
end

-- -----------------------------------------------------------------------
--  MySQL über die oxmysql-Exports (ohne @oxmysql/lib, damit die Resource
--  auch ohne oxmysql startet)
-- -----------------------------------------------------------------------
local Sql = {}
local cache = {}        -- Schlüssel -> JSON-Text (wie in der KVP)
local dirty = {}        -- Schlüssel, die noch in die Datenbank müssen
local logQueue = {}     -- INSERTs für die Protokoll-Tabellen
local inFlight = false
local lastError = 0

local function ox() return exports.oxmysql end

-- Abfrage abwarten (mit Zeitlimit, falls oxmysql bei einem Fehler nie antwortet)
function Sql.await(query, values, timeoutMs)
    local p = promise.new()
    local done = false
    local function finish(result)
        if done then return end
        done = true
        p:resolve(result)
    end
    local ok, err = pcall(function()
        ox():query(query, values or {}, function(result) finish(result) end)
    end)
    if not ok then
        warn('MySQL-Fehler: ' .. tostring(err))
        return nil
    end
    SetTimeout(timeoutMs or 20000, function() finish(nil) end)
    return Citizen.Await(p)
end

-- SQL-Datei der Resource in einzelne Befehle teilen (Kommentare raus)
function Sql.schema()
    local text = LoadResourceFile(GetCurrentResourceName(), 'bodyshot.sql') or ''
    local lines = {}
    for line in (text .. '\n'):gmatch('(.-)\r?\n') do
        if not line:match('^%s*%-%-') then lines[#lines + 1] = line end
    end
    local out = {}
    for stmt in (table.concat(lines, '\n') .. ';'):gmatch('(.-);') do
        stmt = stmt:match('^%s*(.-)%s*$')
        if stmt ~= '' then out[#out + 1] = stmt end
    end
    return out
end

local function q(query, values) return { query = query, values = values } end
local function bool(v) return v and 1 or 0 end
local function enc(v) return json.encode(v) end
local function dec(raw)
    if type(raw) ~= 'string' or raw == '' then return nil end
    local ok, v = pcall(json.decode, raw)
    if ok then return v end
    return nil
end

local UPSERT_ACC = 'INSERT INTO `bs_accounts` (`id`, `license`, `name`, `money`, `xp`, `premium`, `kills`, `deaths`, `best_streak`, `gw_wins`, '
    .. '`duel_wins`, `duel_losses`, `login_streak`, `play_seconds`, `created_at`, `last_login`, `data`) '
    .. 'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE '
    .. '`license` = VALUES(`license`), `name` = VALUES(`name`), `money` = VALUES(`money`), `xp` = VALUES(`xp`), `premium` = VALUES(`premium`), '
    .. '`kills` = VALUES(`kills`), `deaths` = VALUES(`deaths`), `best_streak` = VALUES(`best_streak`), `gw_wins` = VALUES(`gw_wins`), '
    .. '`duel_wins` = VALUES(`duel_wins`), `duel_losses` = VALUES(`duel_losses`), `login_streak` = VALUES(`login_streak`), '
    .. '`play_seconds` = VALUES(`play_seconds`), `last_login` = VALUES(`last_login`), `data` = VALUES(`data`)'
local UPSERT_TEAM = 'INSERT INTO `bs_teams` (`id`, `name`, `tag`, `color`, `leader`, `members`, `data`) VALUES (?, ?, ?, ?, ?, ?, ?) '
    .. 'ON DUPLICATE KEY UPDATE `name` = VALUES(`name`), `tag` = VALUES(`tag`), `color` = VALUES(`color`), `leader` = VALUES(`leader`), '
    .. '`members` = VALUES(`members`), `data` = VALUES(`data`)'
local UPSERT_ZONE = 'INSERT INTO `bs_zones` (`zone_key`, `owner`, `cooldown_until`) VALUES (?, ?, ?) '
    .. 'ON DUPLICATE KEY UPDATE `owner` = VALUES(`owner`), `cooldown_until` = VALUES(`cooldown_until`)'
local INSERT_HOOD = 'INSERT INTO `bs_hoods` (`team_key`, `data`) VALUES (?, ?)'
local UPSERT_BAN = 'INSERT INTO `bs_bans` (`license`, `account_id`, `name`, `reason`, `banned_by`, `until_ts`, `created_ts`) VALUES (?, ?, ?, ?, ?, ?, ?) '
    .. 'ON DUPLICATE KEY UPDATE `account_id` = VALUES(`account_id`), `name` = VALUES(`name`), `reason` = VALUES(`reason`), '
    .. '`banned_by` = VALUES(`banned_by`), `until_ts` = VALUES(`until_ts`), `created_ts` = VALUES(`created_ts`)'
local UPSERT_BOUNTY = 'INSERT INTO `bs_bounties` (`target_id`, `amount`, `data`) VALUES (?, ?, ?) '
    .. 'ON DUPLICATE KEY UPDATE `amount` = VALUES(`amount`), `data` = VALUES(`data`)'
local UPSERT_COUNTER = 'INSERT INTO `bs_counters` (`name`, `value`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `value` = VALUES(`value`)'
local UPSERT_KV = 'INSERT INTO `bs_kv` (`k`, `v`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `v` = VALUES(`v`)'

-- Welche SQL-Befehle braucht ein geänderter Schlüssel?
local function statementsFor(key, raw)
    local value = dec(raw)
    if key == 'zones' then
        local out = {}
        for zoneKey, s in pairs(type(value) == 'table' and value or {}) do
            out[#out + 1] = q(UPSERT_ZONE, { tostring(zoneKey), type(s) == 'table' and s.owner or '' or '', int(type(s) == 'table' and s.cooldownUntil or 0) })
        end
        return out
    elseif key == 'hoods' then
        local out = { q('DELETE FROM `bs_hoods`', {}) }
        for teamKey, h in pairs(type(value) == 'table' and value or {}) do
            out[#out + 1] = q(INSERT_HOOD, { tostring(teamKey), enc(h) })
        end
        return out
    end
    local kind, id = key:match('^(%a+):(.+)$')
    if kind == 'acc' then
        if type(value) ~= 'table' then return { q('DELETE FROM `bs_accounts` WHERE `id` = ?', { int(id) }) } end
        local st = value.stats or {}
        return { q(UPSERT_ACC, {
            int(value.id), tostring(value.license or ('none:' .. int(value.id))), tostring(value.name or ('user' .. int(value.id))),
            int(value.money), int(value.xp), bool(value.premium == true),
            int(st.kills), int(st.deaths), int(st.best), int(st.gwWins), int(st.duelWins), int(st.duelLosses),
            int(value.login and value.login.streak), int(value.playSeconds), int(value.created), int(value.lastLogin), raw,
        }) }
    elseif kind == 'team' then
        if type(value) ~= 'table' then return { q('DELETE FROM `bs_teams` WHERE `id` = ?', { int(id) }) } end
        return { q(UPSERT_TEAM, { int(value.id), tostring(value.name or ''), tostring(value.tag or ''), tostring(value.color or '#2f80ff'),
            int(value.leader), #(value.members or {}), raw }) }
    elseif kind == 'ban' then
        if type(value) ~= 'table' then return { q('DELETE FROM `bs_bans` WHERE `license` = ?', { id }) } end
        return { q(UPSERT_BAN, { id, value.uid ~= nil and int(value.uid) or -1, tostring(value.name or ''), tostring(value.reason or ''):sub(1, 255),
            tostring(value.by or ''), int(value['until']), int(value.at) }) }
    elseif kind == 'bounty' then
        if type(value) ~= 'table' then return { q('DELETE FROM `bs_bounties` WHERE `target_id` = ?', { int(id) }) } end
        return { q(UPSERT_BOUNTY, { int(id), int(value.amount), raw }) }
    elseif kind == 'next' then
        return { q(UPSERT_COUNTER, { id, int(value) }) }
    elseif kind == 'lic' or kind == 'name' then
        return {}                                  -- steht schon in bs_accounts
    end
    if raw == nil then return { q('DELETE FROM `bs_kv` WHERE `k` = ?', { key }) } end
    return { q(UPSERT_KV, { key, raw }) }
end

-- Alles aus der Datenbank in den Speicher laden
local function loadEverything()
    cache = {}
    local accounts = Sql.await('SELECT * FROM `bs_accounts`') or {}
    local maxId = -1
    for _, row in ipairs(accounts) do
        local acc = dec(row.data) or {}
        acc.id = int(row.id)
        acc.license = row.license
        acc.name = row.name
        acc.money = int(row.money)          -- diese Spalten darf man in der DB ändern
        acc.xp = int(row.xp)
        acc.premium = int(row.premium) == 1
        cache['acc:' .. acc.id] = enc(acc)
        if row.license and not tostring(row.license):find('^none:') then cache['lic:' .. row.license] = enc(acc.id) end
        cache['name:' .. string.lower(row.name)] = enc(acc.id)
        if acc.id > maxId then maxId = acc.id end
    end
    for _, row in ipairs(Sql.await('SELECT * FROM `bs_teams`') or {}) do
        local t = dec(row.data)
        if type(t) == 'table' then
            t.id = int(row.id)
            cache['team:' .. t.id] = enc(t)
        end
    end
    local zones = Sql.await('SELECT * FROM `bs_zones`') or {}
    if #zones > 0 then
        local z = {}
        for _, row in ipairs(zones) do
            z[row.zone_key] = { owner = (row.owner ~= nil and row.owner ~= '') and row.owner or false, cooldownUntil = int(row.cooldown_until) }
        end
        cache['zones'] = enc(z)
    end
    local hoods = Sql.await('SELECT * FROM `bs_hoods`') or {}
    if #hoods > 0 then
        local h = {}
        for _, row in ipairs(hoods) do h[row.team_key] = dec(row.data) end
        cache['hoods'] = enc(h)
    end
    for _, row in ipairs(Sql.await('SELECT * FROM `bs_bans`') or {}) do
        cache['ban:' .. row.license] = enc({
            name = row.name, uid = int(row.account_id) >= 0 and int(row.account_id) or nil, reason = row.reason,
            by = row.banned_by, at = int(row.created_ts), ['until'] = int(row.until_ts),
        })
    end
    for _, row in ipairs(Sql.await('SELECT * FROM `bs_bounties`') or {}) do
        local b = dec(row.data) or {}
        b.amount = int(row.amount)
        cache['bounty:' .. int(row.target_id)] = enc(b)
    end
    local counters = Sql.await('SELECT * FROM `bs_counters`') or {}
    for _, row in ipairs(counters) do cache['next:' .. row.name] = enc(int(row.value)) end
    for _, row in ipairs(Sql.await('SELECT * FROM `bs_kv`') or {}) do cache[row.k] = row.v end

    -- Sicherheitsnetz: die nächste User-ID liegt immer hinter der größten vorhandenen
    if maxId >= 0 and int(dec(cache['next:user'])) <= maxId then
        cache['next:user'] = enc(maxId + 1)
        dirty['next:user'] = true
    end
    return #accounts, #counters
end

-- v3-Daten aus der KVP in die (leere) Datenbank übernehmen
local function migrateFromKvp()
    local keys = Kvp.keys('')
    local n, accounts = 0, 0
    for _, key in ipairs(keys) do
        local raw = Kvp.raw(key)
        if raw and raw ~= '' and dec(raw) ~= nil then
            cache[key] = raw
            dirty[key] = true
            n = n + 1
            if key:find('^acc:') then accounts = accounts + 1 end
        end
    end
    if n > 0 then
        cache['meta:migrated'] = enc({ at = os.time(), keys = n, accounts = accounts })
        dirty['meta:migrated'] = true
        DB.migrated = true
        log(('Alte KVP-Daten übernommen: %d Accounts (%d Einträge). Die KVP bleibt als Sicherung erhalten.'):format(accounts, n))
    end
    return n
end

-- Gesammelte Änderungen in EINER Transaktion schreiben
function DB.flush(force)
    if DB.mode ~= 'mysql' then return false end
    if inFlight and not force then return false end
    if next(dirty) == nil and #logQueue == 0 then return false end
    local queries, keys = {}, {}
    for key in pairs(dirty) do
        keys[#keys + 1] = key
        for _, stmt in ipairs(statementsFor(key, cache[key])) do queries[#queries + 1] = stmt end
    end
    local logs = logQueue
    for _, stmt in ipairs(logs) do queries[#queries + 1] = stmt end
    dirty, logQueue = {}, {}
    if #queries == 0 then return false end
    inFlight = true
    local ok, err = pcall(function()
        ox():transaction(queries, nil, function(success)
            inFlight = false
            if success then
                DB.lastFlush = os.time()
                DB.status = 'MySQL verbunden'
            else
                for _, key in ipairs(keys) do dirty[key] = true end       -- nochmal versuchen
                for _, stmt in ipairs(logs) do logQueue[#logQueue + 1] = stmt end
                DB.failures = DB.failures + 1
                DB.status = 'MySQL: Speichern fehlgeschlagen – neuer Versuch läuft'
                if os.time() - lastError > 30 then
                    lastError = os.time()
                    warn('Speichern in MySQL fehlgeschlagen (Details stehen oben von oxmysql). Neuer Versuch jede Sekunde.')
                end
            end
        end)
    end)
    if not ok then
        inFlight = false
        for _, key in ipairs(keys) do dirty[key] = true end
        for _, stmt in ipairs(logs) do logQueue[#logQueue + 1] = stmt end
        warn('oxmysql nicht erreichbar: ' .. tostring(err))
    end
    return true
end

function DB.pending()
    local n = #logQueue
    for _ in pairs(dirty) do n = n + 1 end
    return n
end

-- -----------------------------------------------------------------------
--  Start
-- -----------------------------------------------------------------------
local function wantMysql()
    local mode = cfg().mode or 'auto'
    if mode == 'kvp' then return false, 'kvp' end
    local state = GetResourceState('oxmysql')
    if mode == 'auto' and (state == 'missing' or state == 'unknown' or state == nil) then return false, 'auto' end
    -- läuft oxmysql noch an? kurz warten
    local deadline = GetGameTimer() + 15000
    while state ~= 'started' and GetGameTimer() < deadline do
        Wait(250)
        state = GetResourceState('oxmysql')
    end
    if state ~= 'started' then
        if mode == 'auto' then
            warn('oxmysql ist installiert, läuft aber nicht ("ensure oxmysql" fehlt?) – benutze KVP.')
            return false, 'auto'
        end
        return true, mode
    end
    return true, mode
end

function DB.init()
    local useSql = wantMysql()
    if not useSql then
        DB.mode = 'kvp'
        DB.status = 'KVP (ohne Datenbank)'
        DB.ready = true
        log('Speicher: Resource-KVP (keine Datenbank). Für MySQL: oxmysql starten – siehe README.')
        return
    end

    DB.mode = 'mysql'
    -- Verbindung abwarten
    local tries = 0
    while true do
        local res = Sql.await('SELECT 1 AS ok', {}, 15000)
        if type(res) == 'table' then break end
        tries = tries + 1
        DB.status = 'Warte auf MySQL … (Versuch ' .. tries .. ')'
        if tries == 1 or tries % 6 == 0 then
            warn('MySQL nicht erreichbar. Prüf "set mysql_connection_string" in der server.cfg. Spieler können erst rein, wenn die Datenbank da ist.')
        end
        Wait(5000)
    end

    for _, stmt in ipairs(Sql.schema()) do Sql.await(stmt, {}) end
    local accounts, counters = loadEverything()
    if accounts == 0 and counters == 0 and cache['meta:migrated'] == nil then
        migrateFromKvp()
    end
    DB.flush()
    DB.status = 'MySQL verbunden'
    DB.ready = true
    log(('Speicher: MySQL (oxmysql) – %d Accounts geladen.'):format(DB.countPrefix('acc:')))

    CreateThread(function()
        while true do
            Wait(FLUSH_MS)
            DB.flush()
        end
    end)
end

-- Bis zum Ende des Starts warten (Join, Login)
function DB.waitReady(timeoutMs)
    local deadline = GetGameTimer() + (timeoutMs or 120000)
    while not DB.ready and GetGameTimer() < deadline do Wait(100) end
    return DB.ready
end

-- -----------------------------------------------------------------------
--  API (gleich für beide Speicher)
-- -----------------------------------------------------------------------
function DB.get(key)
    if DB.mode == 'mysql' then return dec(cache[key]) end
    return Kvp.get(key)
end

function DB.set(key, value)
    if DB.mode == 'mysql' then
        cache[key] = value ~= nil and enc(value) or nil
        dirty[key] = true
        return
    end
    Kvp.set(key, value)
end

-- alle Schlüssel mit diesem Präfix (ohne "gw:")
function DB.keys(prefix)
    if DB.mode == 'mysql' then
        local out = {}
        for key in pairs(cache) do
            if key:sub(1, #prefix) == prefix then out[#out + 1] = key end
        end
        table.sort(out)
        return out
    end
    return Kvp.keys(prefix)
end

function DB.countPrefix(prefix)
    local n = 0
    for _ in ipairs(DB.keys(prefix)) do n = n + 1 end
    return n
end

-- Protokoll-Zeile (nur MySQL; ohne Datenbank wird nichts protokolliert)
local LOGS = {
    case = { 'bs_case_log', { 'account_id', 'case_key', 'skin_key', 'rarity', 'duplicate', 'created_at' } },
    duel = { 'bs_duel_log', { 'winner_id', 'loser_id', 'score', 'stake', 'weapon', 'arena', 'reason', 'created_at' } },
    bounty = { 'bs_bounty_log', { 'target_id', 'hunter_id', 'amount', 'created_at' } },
}
function DB.log(kind, row)
    if DB.mode ~= 'mysql' then return end
    local def = LOGS[kind]
    if not def then return end
    local cols, marks, values = {}, {}, {}
    for _, c in ipairs(def[2]) do
        cols[#cols + 1] = '`' .. c .. '`'
        marks[#marks + 1] = '?'
        local v = row[c]
        if c == 'created_at' and v == nil then v = os.time() end
        if type(v) == 'boolean' then v = v and 1 or 0 end
        if v == nil then v = (c:find('_id$') or c == 'stake' or c == 'amount') and 0 or '' end
        values[#values + 1] = v
    end
    logQueue[#logQueue + 1] = q(('INSERT INTO `%s` (%s) VALUES (%s)'):format(def[1], table.concat(cols, ', '), table.concat(marks, ', ')), values)
end

-- Fortlaufende Nummern: nextId('user') liefert 0, 1, 2, ...
function DB.nextId(counter)
    local n = int(DB.get('next:' .. counter))
    DB.set('next:' .. counter, n + 1)
    return n
end

function DB.loadAccount(id) return DB.get('acc:' .. int(id)) end
function DB.saveAccount(acc) DB.set('acc:' .. int(acc.id), acc) end

function DB.accountIdByLicense(license)
    local v = DB.get('lic:' .. license)
    if v == nil then return nil end
    return int(v)
end
function DB.linkLicense(license, id) DB.set('lic:' .. license, int(id)) end

function DB.accountIdByName(name)
    local v = DB.get('name:' .. string.lower(name))
    if v == nil then return nil end
    return int(v)
end
function DB.linkName(name, id) DB.set('name:' .. string.lower(name), int(id)) end
function DB.unlinkName(name) DB.set('name:' .. string.lower(name), nil) end

-- Banns: ban:<license> = { by, reason, until (0 = für immer), name, uid, at }
function DB.getBan(license) return license and DB.get('ban:' .. license) or nil end
function DB.setBan(license, ban) DB.set('ban:' .. license, ban) end
function DB.listBans()
    local out = {}
    for _, key in ipairs(DB.keys('ban:')) do
        local b = DB.get(key)
        if type(b) == 'table' then
            b.license = string.sub(key, 5)
            out[#out + 1] = b
        end
    end
    return out
end
