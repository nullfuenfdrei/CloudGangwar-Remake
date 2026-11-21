-- =======================================================================
--  Logs: Datei + Discord-Webhooks
--  - Datei: <Server-Ordner>/logs/bodyshot-JJJJ-MM-TT.log (alles)
--  - Webhook "logs": Joins, Admin, Banns, Gangwar … (siehe Config.Logs)
--  - Webhook "anticheat": jede Anticheat-Erkennung
--  Links kommen aus der server.cfg (bodyshot_webhook_logs / _anticheat).
--  IP-Adressen werden nie geloggt.
-- =======================================================================

Logs = {}

local COLORS = {
    join = 0x34e39a, leave = 0x8b9aab, register = 0x19b2ff, admin = 0xffc24a, ban = 0xff4d61,
    gangwar = 0xf23d4f, team = 0x8a5cff, shop = 0x2f80ff, wheel = 0xffb020, case = 0xb45cff,
    kill = 0x5a6b7d, chat = 0x42505e, ac = 0xff2244, server = 0x19b2ff,
}
local TITLES = {
    join = 'Verbunden', leave = 'Verlassen', register = 'Neuer Account', admin = 'Admin', ban = 'Bann / Kick',
    gangwar = 'Gangwar', team = 'Team', shop = 'Shop', wheel = 'Glücksrad', case = 'Case', kill = 'Kill',
    chat = 'Chat', ac = 'Anticheat', server = 'Server',
}

local queues = { logs = {}, anticheat = {} }
local folder

-- Erster Ordner, in den der Server schreiben darf:
-- 1. <Server-Ordner>/logs  2. <Resource>/logs
local function writable(dir)
    local probe = io.open(dir .. '/.probe', 'w')
    if not probe then return false end
    probe:close()
    os.remove(dir .. '/.probe')
    return true
end

local function logFolder()
    if folder ~= nil then return folder end
    local res = GetResourcePath(GetCurrentResourceName()):gsub('\\', '/')
    local base = res:match('^(.*)/resources/') or res
    for _, dir in ipairs({ base .. '/logs', res .. '/logs' }) do
        if writable(dir) then folder = dir return folder end
    end
    folder = false
    return folder
end

-- Sicherheitsnetz: IPs und Webhook-Links aus jedem Text entfernen
local function scrub(text)
    text = tostring(text or '')
    text = text:gsub('%d+%.%d+%.%d+%.%d+', '[IP entfernt]')
    text = text:gsub('https?://[%w%.]*discord[%w%.]*/api/webhooks/%S+', '[Webhook]')
    return text
end

local function writeFile(line)
    if not (Config.Logs and Config.Logs.file) or not logFolder() then return end
    local path = ('%s/bodyshot-%s.log'):format(logFolder(), os.date('%Y-%m-%d'))
    local f = io.open(path, 'a')
    if not f then return end
    f:write(line, '\n')
    f:close()
end

-- Spieler als kurze Zeile: Name #ID (Spieler-ID, Discord)
function Logs.who(p)
    if not p then return 'Konsole' end
    if type(p) == 'number' then
        if p == 0 then return 'Konsole' end
        p = Players[p] or { src = p }
    end
    local name = p.acc and p.acc.name or GetPlayerName(p.src) or '?'
    local s = p.acc and ('%s #%d'):format(name, p.acc.id) or name
    s = s .. (' [Spieler-ID %s]'):format(tostring(p.src))
    local discord
    for _, id in ipairs(GetPlayerIdentifiers(p.src) or {}) do
        if id:sub(1, 8) == 'discord:' then discord = id:sub(9) end
    end
    if discord then s = s .. (' <@%s>'):format(discord) end
    return s
end

-- Lizenz für Banns/Anticheat (keine IP)
function Logs.ids(src)
    local out = {}
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        local kind = id:match('^(%a+%d?):')
        if kind == 'license' or kind == 'discord' or kind == 'fivem' or kind == 'steam' then out[#out + 1] = id end
    end
    return table.concat(out, '\n')
end

local function queue(channel, embed)
    local q = queues[channel]
    q[#q + 1] = embed
    if #q > 200 then table.remove(q, 1) end          -- Discord down? Nicht ewig sammeln
end

-- category: siehe COLORS. fields = { { name, value }, ... } (optional)
function Logs.add(category, text, fields)
    text = scrub(text)
    local stamp = os.date('%Y-%m-%d %H:%M:%S')
    local line = ('[%s] [%s] %s'):format(stamp, string.upper(category), text)
    if fields then
        for _, f in ipairs(fields) do line = line .. (' | %s: %s'):format(f[1], scrub(f[2]):gsub('\n', ', ')) end
    end
    writeFile(line)

    local channel = category == 'ac' and 'anticheat' or 'logs'
    if channel == 'logs' and not (Config.Logs and Config.Logs.webhook and Config.Logs.webhook[category]) then return end
    local embed = {
        title = TITLES[category] or category,
        description = text:sub(1, 2000),
        color = COLORS[category] or COLORS.server,
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        footer = { text = ('%s %s'):format(Config.ServerName or '', Config.ServerTag or '') },
    }
    if fields then
        embed.fields = {}
        for i, f in ipairs(fields) do
            if i > 20 then break end
            embed.fields[#embed.fields + 1] = { name = tostring(f[1]):sub(1, 250), value = scrub(f[2]):sub(1, 1000), inline = f[3] == true }
        end
    end
    queue(channel, embed)
end

-- Gesammelt senden: höchstens 10 Embeds pro Nachricht, alle 2 Sekunden
local CONVARS = { logs = 'bodyshot_webhook_logs', anticheat = 'bodyshot_webhook_anticheat' }
local waitUntil = { logs = 0, anticheat = 0 }

local function flush(channel)
    local q = queues[channel]
    if #q == 0 or GetGameTimer() < waitUntil[channel] then return end
    local url = GetConvar(CONVARS[channel], '')
    if url == '' or not url:match('^https://[%w%.]*discord[%w%.]*%.com/api/webhooks/') then
        queues[channel] = {}
        return
    end
    local batch = {}
    for i = 1, math.min(10, #q) do batch[i] = table.remove(q, 1) end
    PerformHttpRequest(url, function(status, _, headers)
        if status == 429 then
            -- zu schnell: zurück in die Schlange und kurz warten
            for i = #batch, 1, -1 do table.insert(queues[channel], 1, batch[i]) end
            local retry = tonumber(headers and (headers['retry-after'] or headers['Retry-After'])) or 5
            waitUntil[channel] = GetGameTimer() + math.ceil(retry * 1000)
        elseif status < 200 or status >= 300 then
            print(('^1[bodyshot_pvp] Webhook (%s) antwortet mit %s^7'):format(channel, tostring(status)))
        end
    end, 'POST', json.encode({ username = (Config.ServerName or 'Server') .. ' Logs', embeds = batch }), { ['Content-Type'] = 'application/json' })
end

CreateThread(function()
    local folderReady = false
    while true do
        Wait(2000)
        if not folderReady then
            folderReady = true
            if logFolder() then print('^5[bodyshot_pvp]^7 Logs: ' .. logFolder())
            else print('^3[bodyshot_pvp] Kein beschreibbarer Log-Ordner (logs/) – nur Discord-Logs.^7') end
        end
        flush('logs')
        flush('anticheat')
    end
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    Logs.add('server', ('Server gestartet – %s %s'):format(Config.ServerName or '', Config.ServerTag or ''))
end)
