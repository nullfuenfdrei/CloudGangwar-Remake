-- =======================================================================
--  Chat: Global + Team, mit Spam-Schutz und Stummschalten
--  Befehle (/...) führt der Client selbst aus.
-- =======================================================================

ChatSys = {}

local function clean(text)
    text = tostring(text or '')
    text = text:gsub('[%c]', ' ')          -- keine Steuerzeichen
    text = text:gsub('%^%d', '')           -- keine Farbcodes von Spielern
    text = text:gsub('~%a~', '')           -- keine GTA-Textcodes
    text = Util.trim(text)
    local max = Config.Chat and Config.Chat.maxLength or 150
    if #text > max then text = text:sub(1, max) end
    return text
end
ChatSys.clean = clean

local function rateLimited(p)
    local now = Now()
    local window = (Config.Chat and Config.Chat.rateSeconds or 4) * 1000
    local count = Config.Chat and Config.Chat.rateCount or 3
    local keep = {}
    for _, t in ipairs(p.chatTimes) do
        if now - t < window then keep[#keep + 1] = t end
    end
    p.chatTimes = keep
    if #keep >= count then return true end
    keep[#keep + 1] = now
    return false
end

function ChatSys.mutedFor(acc)
    local left = (acc.mutedUntil or 0) - os.time()
    return left > 0 and left or 0
end

function ChatSys.send(p, channel, text)
    text = clean(text)
    if text == '' then return end
    local muted = ChatSys.mutedFor(p.acc)
    if muted > 0 then
        return Notify(p.src, 'error', ('Du bist stummgeschaltet (noch %d min).'):format(math.ceil(muted / 60)))
    end
    if rateLimited(p) then
        return Notify(p.src, 'error', 'Nicht so schnell – warte kurz.')
    end
    local info = Teams.info(p.team)
    if channel == 'team' and not info then channel = 'all' end
    local msg = {
        kind = 'player', channel = channel == 'team' and 'team' or 'all',
        name = p.acc.name, uid = p.acc.id,
        tag = info and info.tag or nil, color = info and info.color or nil,
        text = text,
        rank = (Config.Staff and Config.Staff.showInChat) and Staff.info(Staff.rank(p.src)) or nil,
    }
    local key = info and info.key
    for _, q in pairs(Players) do
        if q.loggedIn and (msg.channel == 'all' or Teams.key(q.team) == key) then
            TriggerClientEvent('bspvp:chat', q.src, msg)
        end
    end
    print(('[Chat%s] %s #%d: %s'):format(msg.channel == 'team' and '/Team' or '', p.acc.name, p.acc.id, text))
    Logs.add('chat', ('[%s] %s: %s'):format(msg.channel == 'team' and 'Team' or 'Alle', Logs.who(p), text))
    TriggerEvent('chatMessage', p.src, p.acc.name, text)
end

RegisterNetEvent('bspvp:chat:send', function(channel, text)
    local p = Players[source]
    if not p or not p.loggedIn or not p.acc then return end
    ChatSys.send(p, tostring(channel or 'all'), text)
end)
