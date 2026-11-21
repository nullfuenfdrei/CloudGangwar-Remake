-- =======================================================================
--  Client: eigener Chat (oben links). T = schreiben, Tab = Alle/Team,
--  / am Anfang = Befehl. Versteht auch die Events des Standard-Chats,
--  damit Nachrichten anderer Ressourcen hier erscheinen.
-- =======================================================================

Chat = { open = false, channel = 'all', suggestions = {} }

local function nui(data) SendNUIMessage(data) end

function Chat.close()
    if not Chat.open then return end
    Chat.open = false
    SetNuiFocus(false, false)
    nui({ type = 'chatClose' })
end

RegisterCommand('gwchat', function()
    if Chat.open or UI.screen ~= nil or not PvP.loggedIn or IsPauseMenuActive() then return end
    Chat.open = true
    SetNuiFocus(true, false)
    SetNuiFocusKeepInput(false)
    nui({ type = 'chatOpen', channel = Chat.channel })
end, false)
RegisterKeyMapping('gwchat', 'Chat öffnen', 'keyboard', Config.Keys.chat or 'T')

RegisterNUICallback('chatSend', function(data, cb)
    local text = tostring(data and data.text or ''):sub(1, 300)
    local channel = (data and data.channel == 'team') and 'team' or 'all'
    Chat.channel = channel
    Chat.close()
    text = text:gsub('^%s+', ''):gsub('%s+$', '')
    if text ~= '' then
        if text:sub(1, 1) == '/' then
            ExecuteCommand(text:sub(2))
        else
            TriggerServerEvent('bspvp:chat:send', channel, text)
        end
    end
    cb({})
end)

RegisterNUICallback('chatClose', function(data, cb)
    if data and (data.channel == 'team' or data.channel == 'all') then Chat.channel = data.channel end
    Chat.close()
    cb({})
end)

RegisterNetEvent('bspvp:chat', function(msg)
    if type(msg) == 'table' then nui({ type = 'chat', msg = msg }) end
end)

-- -----------------------------------------------------------------------
--  Standard-Chat-Events (andere Ressourcen, txAdmin, Befehle)
-- -----------------------------------------------------------------------
local function toHex(c)
    if type(c) ~= 'table' or #c < 3 then return nil end
    return ('#%02x%02x%02x'):format(math.floor(c[1]) % 256, math.floor(c[2]) % 256, math.floor(c[3]) % 256)
end

local function legacy(author, color, text)
    nui({ type = 'chat', msg = { kind = 'legacy', name = author and tostring(author) or nil, color = toHex(color), text = tostring(text or '') } })
end

RegisterNetEvent('chat:addMessage', function(m)
    if type(m) == 'string' then return legacy(nil, nil, m) end
    if type(m) ~= 'table' then return end
    local args = m.args or {}
    if #args >= 2 then
        legacy(args[1], m.color, table.concat(args, ' ', 2))
    elseif #args == 1 then
        legacy(nil, m.color, args[1])
    elseif m.template then
        legacy(nil, m.color, (tostring(m.template):gsub('<[^>]->', '')))       -- kein HTML aus fremden Quellen
    end
end)

RegisterNetEvent('chatMessage', function(author, color, text)
    legacy(author ~= '' and author or nil, color, text)
end)

RegisterNetEvent('chat:clear', function()
    nui({ type = 'chatClear' })
end)

local function pushSuggestions()
    local list = {}
    for name, s in pairs(Chat.suggestions) do
        list[#list + 1] = { name = name, help = s.help, params = s.params }
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    nui({ type = 'chatSuggestions', list = list })
end

local pending = false
local function queuePush()
    if pending then return end
    pending = true
    SetTimeout(250, function()
        pending = false
        pushSuggestions()
    end)
end

RegisterNetEvent('chat:addSuggestion', function(name, help, params)
    if type(name) ~= 'string' then return end
    if name:sub(1, 1) ~= '/' then name = '/' .. name end
    local clean = {}
    for _, p in ipairs(type(params) == 'table' and params or {}) do
        if type(p) == 'table' then clean[#clean + 1] = { name = tostring(p.name or ''), help = tostring(p.help or '') } end
    end
    Chat.suggestions[name] = { help = tostring(help or ''), params = clean }
    queuePush()
end)

RegisterNetEvent('chat:addSuggestions', function(list)
    for _, s in ipairs(type(list) == 'table' and list or {}) do
        if type(s) == 'table' then TriggerEvent('chat:addSuggestion', s.name, s.help, s.params) end
    end
end)

RegisterNetEvent('chat:removeSuggestion', function(name)
    if type(name) ~= 'string' then return end
    if name:sub(1, 1) ~= '/' then name = '/' .. name end
    Chat.suggestions[name] = nil
    queuePush()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if Chat.open then SetNuiFocus(false, false) end
end)
