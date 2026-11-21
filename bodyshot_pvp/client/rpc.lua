-- =======================================================================
--  Client: Discord Rich Presence
--  Zeigt im Discord-Profil, was man gerade spielt, z. B.
--    "Families · Gangwar Legion Square (12 : 8)"   "Lvl 30 · K/D 2,14 · 5/48 online"
-- =======================================================================

local cfg = Config.DiscordRPC or {}
if cfg.enabled == false or not cfg.appId or cfg.appId == '' then return end

local MODE = { lobby = 'An der Hood', ffa = 'FFA', gangwar = 'Gangwar', duel = '1v1-Duell', select = 'Wählt ein Team', login = 'Im Login' }
local online = 0

RegisterNetEvent('bspvp:hud', function(d)
    if type(d) == 'table' and d.online then online = d.online end
end)

local function kd(s)
    if not s then return '0,00' end
    local v = (s.deaths or 0) > 0 and (s.kills or 0) / s.deaths or (s.kills or 0)
    return (('%.2f'):format(v)):gsub('%.', ',')
end

local function details()
    local team = PvP.team and PvP.team.name
    local place = MODE[PvP.mode] or 'Spielt'
    if PvP.mode == 'gangwar' and PvP.war then
        local w = PvP.war
        local a, d = w.attacker or {}, w.defender or {}
        place = ('Gangwar %s (%d : %d)'):format(w.zoneName or '', a.points or 0, d.points or 0)
    elseif PvP.mode == 'ffa' then
        local a = Config.Arenas[PvP.arenaIndex]
        place = 'FFA ' .. (a and a.name or '')
    elseif PvP.mode == 'lobby' and PvP.hood then
        place = 'Hood ' .. (PvP.hood.name or '')
    end
    return team and (team .. ' · ' .. place) or place
end

local function state()
    local acc = PvP.account
    if not acc then return ('%d online'):format(online) end
    return ('Lvl %d · K/D %s · %d/%d online'):format(acc.level or 1, kd(acc.stats), online, GetConvarInt('sv_maxclients', 48))
end

CreateThread(function()
    SetDiscordAppId(cfg.appId)
    SetDiscordRichPresenceAsset(cfg.largeImage or 'logo')
    SetDiscordRichPresenceAssetText(cfg.largeText or 'Bodyshot Gangwar')
    for i, b in ipairs(cfg.buttons or {}) do
        if i <= 2 and b.label and b.url then SetDiscordRichPresenceAction(i - 1, b.label, b.url) end
    end
    while true do
        if PvP.loggedIn then
            SetRichPresence(details() .. ' | ' .. state())
            if PvP.account and PvP.account.premium then
                SetDiscordRichPresenceAssetSmall(cfg.largeImage or 'logo')
                SetDiscordRichPresenceAssetSmallText(('%s · Premium'):format(PvP.account.name or ''))
            end
        else
            SetRichPresence('Verbindet sich …')
        end
        Wait(math.max(5, cfg.seconds or 15) * 1000)
    end
end)
