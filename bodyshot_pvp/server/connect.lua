-- =======================================================================
--  Verbinden: Bann-Prüfung, Hinweis-Karte (Aufnahmepflicht) und Daten
--  für den Ladebildschirm
-- =======================================================================

local function card(seconds)
    local c = Config.Connect or {}
    local body = {}
    if c.banner and c.banner ~= '' then
        body[#body + 1] = { type = 'Image', url = c.banner, size = 'Stretch' }
    end
    body[#body + 1] = {
        type = 'TextBlock', text = ('%s %s'):format(Config.ServerName, Config.ServerTag or ''),
        size = 'ExtraLarge', weight = 'Bolder', horizontalAlignment = 'Center', color = 'Accent',
    }
    if c.title then
        body[#body + 1] = { type = 'TextBlock', text = c.title, size = 'Large', weight = 'Bolder', horizontalAlignment = 'Center', spacing = 'Large' }
    end
    for _, t in ipairs(c.text or {}) do
        body[#body + 1] = { type = 'TextBlock', text = ('%s  %s'):format(t.flag or '', string.upper(t.lang or '')), weight = 'Bolder', spacing = 'Medium' }
        body[#body + 1] = { type = 'TextBlock', text = t.text or '', wrap = true, spacing = 'Small' }
    end
    body[#body + 1] = {
        type = 'TextBlock', horizontalAlignment = 'Center', spacing = 'ExtraLarge', weight = 'Bolder',
        text = seconds > 0 and ('Verbinde in %d %s …'):format(seconds, seconds == 1 and 'Sekunde' or 'Sekunden') or 'Verbinde …',
    }
    local actions = {}
    if Config.Links and Config.Links.discord and Config.Links.discord ~= '' then
        actions[#actions + 1] = { type = 'Action.OpenUrl', title = 'Discord beitreten', url = Config.Links.discord }
    end
    if Config.Links and Config.Links.store and Config.Links.store ~= '' then
        actions[#actions + 1] = { type = 'Action.OpenUrl', title = 'Shop', url = Config.Links.store }
    end
    return json.encode({
        type = 'AdaptiveCard',
        ['$schema'] = 'http://adaptivecards.io/schemas/adaptive-card.json',
        version = '1.3',
        body = body,
        actions = #actions > 0 and actions or nil,
    })
end

-- Daten, die der Ladebildschirm bekommt (window.nuiHandoverData)
local function handover()
    local zones = {}
    for _, z in ipairs(Config.Zones or {}) do
        local s = Gangwar.zones[z.key] or {}
        local owner = s.owner and Teams.info(Gangwar.refFromKey(s.owner))
        zones[#zones + 1] = { name = z.name, x = z.center.x + 0.0, y = z.center.y + 0.0, r = (z.radius or 80) + 0.0, color = owner and owner.color or nil }
    end
    local hoods = {}
    for _, h in ipairs(Hoods.mapView()) do hoods[#hoods + 1] = { x = h.x, y = h.y, color = h.color } end
    return {
        serverName = Config.ServerName,
        serverTag = Config.ServerTag,
        subtitle = Config.LoadingSubtitle or '',
        welcome = Config.Welcome,
        zones = zones,
        hoods = hoods,
        online = OnlineCount(),
        discord = Config.Links and Config.Links.discord or '',
        store = Config.Links and Config.Links.store or '',
        music = Config.Music or {},
        tips = {
            'Kopf und Körper machen gleich viel Schaden – zielen lohnt sich trotzdem.',
            'Mk-II-Waffen brauchen weniger Treffer bis zum Kill.',
            'Mit F1 wählst du dein Team, mit F2 öffnest du das Hauptmenü.',
            'An deiner Hood parkst du mit E an der Garage Autos aus.',
            'Kills in der Gangwar-Zone geben deinem Team Punkte.',
            'Jede Stunde Spielzeit gibt es einen Bonus.',
        },
    }
end

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    deferrals.update(('Willkommen auf %s – prüfe deinen Account …'):format(Config.ServerName))

    -- Datenbank noch nicht geladen (Server startet gerade)? Kurz warten.
    if not DB.ready then
        deferrals.update('Server startet – Datenbank wird geladen …')
        if not DB.waitReady(60000) then
            deferrals.done('Die Datenbank des Servers ist gerade nicht erreichbar. Versuch es gleich nochmal.')
            return
        end
    end

    local license = GetLicense(src)
    if not license then
        deferrals.done('Keine Rockstar-Lizenz gefunden. Starte FiveM neu und verbinde dich noch einmal.')
        return
    end
    local ban = Admin.activeBan(license)
    if ban then
        deferrals.done(Admin.banText(ban))
        return
    end

    deferrals.handover(handover())

    local c = Config.Connect or {}
    if c.enabled then
        for s = math.max(0, math.floor(c.seconds or 5)), 1, -1 do
            deferrals.presentCard(card(s), function() end)
            Wait(1000)
        end
    end
    deferrals.done()
end)
