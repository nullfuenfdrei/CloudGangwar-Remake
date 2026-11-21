-- =======================================================================
--  Client: Bildschirme (Modus-Auswahl, Teams F1, Hauptmenü F2, Garage,
--  Admin), Kamera hinter dem Login, Ladebildschirm, Einstellungen
-- =======================================================================

UI = {
    screen = nil,          -- 'login' | 'teams' | 'menu' | 'garage' | 'admin' | nil
    cam = nil,
    menuWanted = false,
    teamsClosable = false,
    loginData = nil,
    settings = {},
    loadingClosed = false,
}

local function nui(data) SendNUIMessage(data) end

local function focus(on)
    SetNuiFocus(on, on)
    SetNuiFocusKeepInput(false)
end

-- -----------------------------------------------------------------------
--  Einstellungen (pro Spieler, bleiben gespeichert)
-- -----------------------------------------------------------------------
local KVP = 'bspvp:settings'

local function loadSettings()
    local s = {}
    for k, v in pairs(Config.Hud or {}) do s[k] = v end
    local raw = GetResourceKvpString(KVP)
    if raw and raw ~= '' then
        local ok, saved = pcall(json.decode, raw)
        if ok and type(saved) == 'table' then
            for k, v in pairs(saved) do
                if s[k] ~= nil and type(v) == type(s[k]) then s[k] = v end
            end
        end
    end
    UI.settings = s
end
loadSettings()

local function initMessage()
    return {
        type = 'init',
        settings = UI.settings,
        config = {
            serverName = Config.ServerName, serverTag = Config.ServerTag,
            keys = Config.Keys, discord = Config.Links and Config.Links.discord or '',
            hoodCombat = Config.HoodCombat == true,
            store = Config.Links and Config.Links.store or '',
            chat = { fadeSeconds = Config.Chat and Config.Chat.fadeSeconds or 10, maxLength = Config.Chat and Config.Chat.maxLength or 150 },
            maxHealth = Config.MaxHealth, maxArmour = Config.MaxArmour,
        },
    }
end

-- -----------------------------------------------------------------------
--  Ladebildschirm schließen
-- -----------------------------------------------------------------------
function UI.closeLoading()
    if UI.loadingClosed then return end
    UI.loadingClosed = true
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
end

-- Sicherheitsnetz: falls der Server nie antwortet, nicht ewig im Ladebildschirm hängen
CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(500) end
    Wait(60000)
    if not UI.loadingClosed then
        UI.closeLoading()
        DoScreenFadeIn(500)
    end
end)

-- -----------------------------------------------------------------------
--  Kamera hinter Login/Teamwahl: kreist langsam über der Stadt
-- -----------------------------------------------------------------------
function UI.startCam()
    if UI.cam then return end
    local cfg = Config.LoginCam or { center = Config.Lobby.center, radius = 300.0, height = 150.0, speed = 2.0 }
    local c = cfg.center
    PvP.freezePlayer(true)
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, c.x, c.y, c.z, false, false, false)
    UI.cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', c.x + cfg.radius, c.y, c.z + cfg.height, 0.0, 0.0, 0.0, 50.0, false, 0)
    SetCamActive(UI.cam, true)
    RenderScriptCams(true, false, 0, true, true)
    local cam = UI.cam
    CreateThread(function()
        local angle = math.random() * 360.0
        local last = GetGameTimer()
        while UI.cam == cam do
            local now = GetGameTimer()
            angle = angle + (now - last) / 1000 * (cfg.speed or 1.5)
            last = now
            local a = math.rad(angle)
            local x, y, z = c.x + math.cos(a) * cfg.radius, c.y + math.sin(a) * cfg.radius, c.z + cfg.height
            SetCamCoord(cam, x, y, z)
            PointCamAtCoord(cam, c.x, c.y, c.z)
            SetFocusPosAndVel(x, y, z, 0.0, 0.0, 0.0)
            Wait(0)
        end
        ClearFocus()
    end)
    DoScreenFadeIn(600)
end

function UI.stopCam()
    if not UI.cam then return end
    local cam = UI.cam
    UI.cam = nil
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(cam, false)
    ClearFocus()
end

-- -----------------------------------------------------------------------
--  Bildschirme
-- -----------------------------------------------------------------------
-- Glas-Look: CSS kann die Spielwelt nicht weichzeichnen -> GTA-Bildschirm-Unschärfe
local blurred = false
local function blur(on)
    if on == blurred then return end
    blurred = on
    if on then TriggerScreenblurFadeIn(250) else TriggerScreenblurFadeOut(250) end
end
local BLUR = { menu = true, teams = true, garage = true, admin = true, login = true, help = true }

function UI.openScreen(screen, message)
    if Chat and Chat.open then Chat.close() end
    UI.screen = screen
    focus(true)
    blur(BLUR[screen] == true)
    if message then nui(message) end
end

function UI.close(screen)
    if not UI.screen or (screen and UI.screen ~= screen) then return end
    nui({ type = 'closeScreen', screen = UI.screen })
    UI.screen = nil
    UI.menuWanted = false
    focus(false)
    blur(false)
end

function UI.closeAll()
    nui({ type = 'closeAll' })
    if UI.screen then focus(false) end
    UI.screen = nil
    UI.menuWanted = false
    blur(false)
end

-- -----------------------------------------------------------------------
--  Modus-Auswahl (Login)
-- -----------------------------------------------------------------------
RegisterNetEvent('bspvp:loginScreen', function(data)
    UI.loginData = data
    UI.closeLoading()
    PvP.mode = 'login'
    UI.startCam()
    UI.openScreen('login', initMessage())
    nui({ type = 'login', data = data })
end)

RegisterNetEvent('bspvp:loginError', function(msg)
    nui({ type = 'loginError', text = msg })
end)

RegisterNetEvent('bspvp:loginOk', function(account)
    PvP.account = account
    nui({ type = 'loginOk', account = account })
end)

-- -----------------------------------------------------------------------
--  Teams (F1)
-- -----------------------------------------------------------------------
RegisterNetEvent('bspvp:teamSelect', function(data)
    if type(data) ~= 'table' then return end
    local closable = data.closable
    if closable == nil then closable = PvP.mode == 'lobby' end
    if not closable then
        if PvP.mode == 'lobby' then Garage.forget() end   -- Team verloren: raus aus der Hood
        PvP.mode = 'select'
        PvP.dead = true
        Bodyshot.setGuard(false)
        nui({ type = 'death', show = false })
        UI.startCam()
    end
    UI.teamsClosable = closable
    UI.menuWanted = false
    UI.openScreen('teams', { type = 'teams', data = data, closable = closable })
end)

RegisterNetEvent('bspvp:closeSelect', function()
    UI.close('teams')
end)

RegisterNetEvent('bspvp:joined', function(team)
    nui({ type = 'joined', team = team })
end)

RegisterNetEvent('bspvp:teamInvite', function(inv)
    if type(inv) ~= 'table' then return end
    nui({ type = 'notify', kind = 'war', text = ('%s lädt dich in [%s] %s ein. Annehmen: F2 → Team.'):format(inv.from, inv.tag, inv.team) })
end)

local function teamsKey()
    if UI.screen == 'teams' then
        if UI.teamsClosable then UI.close('teams') end
        return
    end
    if UI.screen ~= nil and UI.screen ~= 'menu' then return end
    if not PvP.loggedIn then return end
    if PvP.mode ~= 'lobby' then
        return HUD.notify('error', 'Teams wechselst du an deiner Hood.')
    end
    TriggerServerEvent('bspvp:teams')
end

RegisterCommand('gwteams', teamsKey, false)
RegisterKeyMapping('gwteams', 'Teams öffnen', 'keyboard', Config.Keys.teams or 'F1')

-- -----------------------------------------------------------------------
--  Hauptmenü (F2)
-- -----------------------------------------------------------------------
local function canOpenMenu()
    return PvP.loggedIn and (PvP.mode == 'lobby' or PvP.inCombat())
end

function UI.openMenu()
    if not canOpenMenu() or (UI.screen ~= nil and UI.screen ~= 'menu') then return end
    UI.menuWanted = true
    TriggerServerEvent('bspvp:menu')
end

RegisterNetEvent('bspvp:menuData', function(data)
    if UI.screen == 'menu' then
        nui({ type = 'menu', data = data })
    elseif UI.menuWanted and canOpenMenu() and UI.screen == nil then
        UI.menuWanted = false
        local page = UI.menuPage
        UI.menuPage = nil
        UI.openScreen('menu', { type = 'menu', data = data, open = true, page = page })
    end
end)

-- Aus F1 heraus direkt eine Menüseite öffnen (z. B. Team gründen)
RegisterNUICallback('openMenuPage', function(data, cb)
    UI.menuPage = data and data.page or nil
    if UI.screen == 'teams' then UI.close('teams') end
    UI.openMenu()
    cb({})
end)

local function menuKey()
    if UI.screen == 'menu' then UI.close('menu') else UI.openMenu() end
end
RegisterCommand('gwmenu', menuKey, false)
RegisterKeyMapping('gwmenu', 'Hauptmenü öffnen', 'keyboard', Config.Keys.menu or 'F2')

-- -----------------------------------------------------------------------
--  NUI -> Lua
-- -----------------------------------------------------------------------
RegisterNUICallback('nuiReady', function(_, cb)
    nui(initMessage())
    if UI.screen == 'login' and UI.loginData then
        nui({ type = 'login', data = UI.loginData })
    end
    if PvP.loggedIn then
        nui({ type = 'mode', mode = PvP.mode, team = PvP.team, uid = PvP.uid, place = PvP.placeName(),
              hood = PvP.hood and PvP.hood.name or nil, serverId = GetPlayerServerId(PlayerId()) })
        if PvP.account then nui({ type = 'account', account = PvP.account }) end
    end
    cb({})
end)

RegisterNUICallback('register', function(data, cb)
    TriggerServerEvent('bspvp:register', tostring(data and data.name or ''), tostring(data and data.ref or ''))
    cb({})
end)

-- Inventar: welche Aufsätze passen auf diese Waffe? (prüft das Spiel selbst)
RegisterNUICallback('weaponComponents', function(data, cb)
    local w = data and Weapons.get(data.weapon)
    cb({ list = w and PvP.attachmentCandidates(w) or {} })
end)

RegisterNUICallback('login', function(_, cb)
    TriggerServerEvent('bspvp:login')
    cb({})
end)

RegisterNUICallback('createTeam', function(data, cb)
    if type(data) == 'table' then
        TriggerServerEvent('bspvp:createTeam', tostring(data.name or ''), tostring(data.tag or ''), tostring(data.color or ''))
    end
    cb({})
end)

RegisterNUICallback('selectTeam', function(data, cb)
    if data and data.kind then
        TriggerServerEvent('bspvp:selectTeam', tostring(data.kind), data.id)
    end
    cb({})
end)

-- Escape / X: nur schließen, was man schließen darf
RegisterNUICallback('closeScreen', function(data, cb)
    local screen = data and data.screen or UI.screen
    if screen == 'wardrobe' then
        Wardrobe.close(false)
    elseif screen == 'teams' then
        if UI.teamsClosable then UI.close('teams') end
    elseif screen ~= 'login' then
        UI.close(screen)
    end
    cb({})
end)

-- Tasten, während ein Bildschirm offen ist (das Spiel bekommt sie dann nicht)
RegisterNUICallback('key', function(data, cb)
    local key = data and data.key
    if key == (Config.Keys.menu or 'F2') then
        if UI.screen == 'menu' then UI.close('menu') end
    elseif key == (Config.Keys.teams or 'F1') then
        if UI.screen == 'teams' then
            if UI.teamsClosable then UI.close('teams') end
        elseif UI.screen == 'menu' then
            TriggerServerEvent('bspvp:changeTeam')
        end
    elseif key == (Config.Keys.admin or 'F6') then
        if UI.screen == 'admin' then UI.close('admin') end
    elseif key == 'F11' then
        if UI.screen == 'help' then UI.close('help') end
    end
    cb({})
end)

RegisterNUICallback('refresh', function(_, cb)
    if UI.screen == 'menu' then TriggerServerEvent('bspvp:menu') end
    cb({})
end)

RegisterNUICallback('settings', function(data, cb)
    if type(data) == 'table' and type(data.settings) == 'table' then
        for k, v in pairs(data.settings) do
            if UI.settings[k] ~= nil and type(v) == type(UI.settings[k]) then UI.settings[k] = v end
        end
        SetResourceKvp(KVP, json.encode(UI.settings))
    end
    cb({})
end)

-- Erlaubte Menü-Aktionen -> Server-Events
local ACTIONS = {
    missionClaim = function(a) TriggerServerEvent('bspvp:missionClaim', tonumber(a.index) or 0) end,
    loginClaim   = function() TriggerServerEvent('bspvp:loginClaim') end,
    caseOpen     = function(a) TriggerServerEvent('bspvp:caseOpen', tostring(a.case)) end,
    skinEquip    = function(a) TriggerServerEvent('bspvp:skinEquip', tostring(a.id)) end,
    skinUnequip  = function(a) TriggerServerEvent('bspvp:skinUnequip', tostring(a.weapon)) end,
    duelChallenge = function(a) TriggerServerEvent('bspvp:duelChallenge', tonumber(a.id) or -1, tonumber(a.arena) or 0, a.weapon and tostring(a.weapon) or nil, tonumber(a.stake) or 0) end,
    duelLeave    = function() TriggerServerEvent('bspvp:duelLeave') end,
    bountyPlace  = function(a) TriggerServerEvent('bspvp:bountyPlace', tonumber(a.id) or -1, tonumber(a.amount) or 0) end,
    joinFFA    = function(a) TriggerServerEvent('bspvp:joinFFA', tonumber(a.index) or 1) end,
    toLobby    = function() TriggerServerEvent('bspvp:toLobby') end,
    gwAttack   = function(a) TriggerServerEvent('bspvp:gwAttack', tostring(a.zone)) end,
    gwJoin     = function(a) TriggerServerEvent('bspvp:gwJoin', tostring(a.zone)) end,
    buy        = function(a) TriggerServerEvent('bspvp:buyWeapon', tostring(a.weapon)) end,
    claim      = function(a) TriggerServerEvent('bspvp:bpClaim', tostring(a.track), tonumber(a.level)) end,
    team       = function(a) TriggerServerEvent('bspvp:team', tostring(a.action), type(a.args) == 'table' and a.args or {}) end,
    changeTeam = function() TriggerServerEvent('bspvp:changeTeam') end,
    holdWeapon = function(a) PvP.holdWeapon(tostring(a.weapon)) end,
    wheelSpin  = function() TriggerServerEvent('bspvp:wheelSpin') end,
    emote      = function(a) Emotes.play(tostring(a.name)) end,
    itemBuy    = function(a) TriggerServerEvent('bspvp:item:buy', tostring(a.kind), tonumber(a.amount) or 1) end,
    attachSet  = function(a) TriggerServerEvent('bspvp:attach:set', tostring(a.weapon), tostring(a.slot), a.component and tostring(a.component) or '') end,
    wardrobe   = function() Wardrobe.show() end,
}
local LEAVES = { joinFFA = true, toLobby = true, gwJoin = true, gwAttack = true, duelLeave = true, holdWeapon = true, emote = true }

-- Glücksrad: Ergebnis an die Seite weitergeben (dreht dort bis zum Feld)
RegisterNetEvent('bspvp:wheelResult', function(data)
    if type(data) == 'table' then nui({ type = 'wheelResult', data = data }) end
end)

-- Menüseite direkt per Befehl öffnen
local function openPageCommand(page)
    return function()
        if UI.screen == 'menu' then
            nui({ type = 'menuPage', page = page })
            return
        end
        UI.menuPage = page
        UI.openMenu()
    end
end
RegisterCommand('gluecksrad', openPageCommand('wheel'), false)
RegisterCommand('wheel', openPageCommand('wheel'), false)
RegisterCommand('inventar', openPageCommand('inventory'), false)
RegisterCommand('emotes', openPageCommand('emotes'), false)
RegisterCommand('gangwar', openPageCommand('gangwar'), false)
RegisterCommand('einladen', openPageCommand('referral'), false)

-- F11: alle Tasten und Befehle
local function helpKey()
    if UI.screen == 'help' then return UI.close('help') end
    if UI.screen ~= nil or not PvP.loggedIn then return end
    TriggerServerEvent('bspvp:help')
end
RegisterCommand('gwhelp', helpKey, false)
RegisterCommand('hilfe', helpKey, false)
RegisterCommand('help', helpKey, false)
RegisterKeyMapping('gwhelp', 'Befehle & Tasten (Hilfe)', 'keyboard', 'F11')

RegisterNetEvent('bspvp:help', function(data)
    if type(data) == 'table' and UI.screen == nil then
        UI.openScreen('help', { type = 'help', data = data })
    end
end)
RegisterCommand('invite', openPageCommand('referral'), false)

RegisterNUICallback('action', function(data, cb)
    local fn = data and ACTIONS[data.action]
    if fn then fn(data) end
    if data and LEAVES[data.action] then UI.close('menu') end       -- Moduswechsel schließt das Menü
    cb({})
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    focus(false)
    blur(false)
    UI.stopCam()
end)
