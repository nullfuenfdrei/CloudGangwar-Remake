-- =======================================================================
--  Client: Spawn, Tod, Modi (Hood / FFA / Gangwar), Waffen, Welt
-- =======================================================================

PvP = {
    loggedIn = false,
    mode = 'login',          -- login | select | lobby (= Hood) | ffa | gangwar | duel
    dead = true,
    spawning = false,
    uid = 0,
    team = nil,              -- { key, kind, id, name, tag, color, outfit }
    hood = nil,              -- { name, spawn, garage, car, radius }
    weapons = {},            -- gekaufte Waffen (Namen)
    respawn = 3,
    arenaIndex = 1,
    zoneKey = nil,
    side = nil,
    war = nil,
    account = nil,
    protected = false,
    protectToken = 0,
    deathToken = 0,
    lastWeapon = nil,
    baseZ = {},
    duel = nil,              -- { id, side, arena = { a, b, center, radius, name }, weapon, opponent }
    duelFreezeUntil = 0,     -- Countdown im Duell: so lange nicht bewegen/schießen
    skins = {},              -- [Waffe] = { id, tint, component } (ausgerüstete Skins)
}

local UNARMED = GetHashKey('WEAPON_UNARMED')

function PvP.nui(data) SendNUIMessage(data) end
local nui = PvP.nui

function PvP.inCombat()
    return PvP.mode == 'ffa' or PvP.mode == 'gangwar' or PvP.mode == 'duel'
end

-- Hat man gerade seine Waffen? (immer, außer in einer Safezone-Hood)
function PvP.armed()
    return PvP.inCombat() or (PvP.mode == 'lobby' and Config.HoodCombat == true)
end

-- -----------------------------------------------------------------------
--  Spawn-Hilfen (Ablauf wie im Standard-spawnmanager)
-- -----------------------------------------------------------------------
local function freezePlayer(freeze)
    local player = PlayerId()
    SetPlayerControl(player, not freeze, false)
    local ped = PlayerPedId()
    if freeze then
        SetEntityVisible(ped, false, false)
        SetEntityCollision(ped, false, false)
        FreezeEntityPosition(ped, true)
        SetPlayerInvincible(player, true)
        if not IsPedFatallyInjured(ped) then ClearPedTasksImmediately(ped) end
    else
        SetEntityVisible(ped, true, false)
        SetEntityCollision(ped, true, true)
        FreezeEntityPosition(ped, false)
        SetPlayerInvincible(player, false)
    end
end
PvP.freezePlayer = freezePlayer

local function waitForCollision(ped, ms)
    local timeout = GetGameTimer() + ms
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        Wait(0)
    end
end

local function groundAt(x, y, fromZ)
    local found, z = GetGroundZFor_3dCoord(x, y, fromZ, false)
    if found then return z end
    return nil
end

local function otherPlayerPositions()
    local list, me = {}, PlayerId()
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= me then
            local ped = GetPlayerPed(pid)
            if ped ~= 0 and not IsEntityDead(ped) then list[#list + 1] = GetEntityCoords(ped) end
        end
    end
    return list
end

local function spotScore(x, y, others)
    local best = 99999.0
    for _, c in ipairs(others) do
        local dx, dy = c.x - x, c.y - y
        local d = math.sqrt(dx * dx + dy * dy)
        if d < best then best = d end
    end
    return best
end

-- Freien Punkt im Kreis finden: Boden auf gleicher Höhe (kein Dach/Container/Wasser),
-- möglichst weit weg von anderen Spielern
local function findSpot(center, radius, cacheKey, lookAt)
    local others = otherPlayerPositions()
    local baseZ = cacheKey and PvP.baseZ[cacheKey]
    if not baseZ then
        baseZ = groundAt(center.x, center.y, center.z + 2.0) or (center.z - 1.0)
        if cacheKey then PvP.baseZ[cacheKey] = baseZ end
    end
    local candidates = {}
    for _ = 1, 40 do
        local angle = math.random() * 2.0 * math.pi
        local dist = math.sqrt(math.random()) * radius
        local x, y = center.x + math.cos(angle) * dist, center.y + math.sin(angle) * dist
        local gz = groundAt(x, y, baseZ + 50.0)
        if gz and math.abs(gz - baseZ) <= 2.0 then
            candidates[#candidates + 1] = vector3(x, y, gz + 1.0)
            if #candidates >= 8 then break end
        end
    end
    local best = vector3(center.x, center.y, center.z)
    local bestScore = -1
    for _, v in ipairs(candidates) do
        local score = spotScore(v.x, v.y, others)
        if score > bestScore then best, bestScore = v, score end
    end
    lookAt = lookAt or center
    local heading = GetHeadingFromVector_2d(lookAt.x - best.x, lookAt.y - best.y)
    return best, heading
end

-- Kampfbereich des aktuellen Modus (Spawn + Zonen-Grenze). An der Hood gibt es keine Grenze.
function PvP.area()
    if PvP.mode == 'ffa' then
        local a = Config.Arenas[PvP.arenaIndex] or Config.Arenas[1]
        return a and { center = a.center, radius = a.radius, key = 'ffa' .. PvP.arenaIndex, name = a.name }
    elseif PvP.mode == 'gangwar' then
        -- radius = Bubble, boundary = Spielfeld mit den Spawns
        local z = PvP.zoneKey and Util.zone(PvP.zoneKey)
        return z and { center = z.center, radius = z.radius, boundary = Util.gwBoundary(z), key = 'gw:' .. z.key, name = z.name, zone = z, bubble = true }
    elseif PvP.mode == 'duel' then
        local a = PvP.duel and PvP.duel.arena
        return a and { center = vector3(a.center.x, a.center.y, a.center.z), radius = a.radius, key = 'duel:' .. tostring(a.key), name = a.name, duel = true }
    end
    return nil
end

function PvP.placeName()
    if PvP.mode == 'lobby' then return PvP.hood and PvP.hood.name or 'Hood' end
    local area = PvP.area()
    return area and area.name or nil
end

local function hoodSpawn()
    local h = PvP.hood
    local s = h and h.spawn
    if not s then
        local c = Config.Lobby.center
        return findSpot(c, 10.0, 'lobby')
    end
    -- Ein paar Meter streuen, damit nicht alle auf demselben Punkt stehen
    local center = vector3(s.x, s.y, s.z)
    local pos = findSpot(center, 3.5, 'hood:' .. (PvP.team and PvP.team.key or '?') .. ':' .. math.floor(s.x) .. ':' .. math.floor(s.y))
    return pos, (s.w or 0.0) + 0.0
end

-- -----------------------------------------------------------------------
--  Gangwar: Spawn auf der Straße (Fahrzeug-Knoten), nie auf Dächern
-- -----------------------------------------------------------------------
local function loadRoadNodes(pos, r)
    if not RequestPathNodesInAreaThisFrame or not AreNodesLoadedForArea then return end
    local timeout = GetGameTimer() + 2500
    while not AreNodesLoadedForArea(pos.x - r, pos.y - r, pos.x + r, pos.y + r) and GetGameTimer() < timeout do
        RequestPathNodesInAreaThisFrame(pos.x - r, pos.y - r, pos.x + r, pos.y + r)
        Wait(0)
    end
end

-- Straßenpunkte rund um "pos", alle außerhalb der Bubble
local function roadSpots(pos, z, count)
    loadRoadNodes(pos, 150.0)
    local out = {}
    for n = 1, count * 3 do
        local ok, node = GetNthClosestVehicleNode(pos.x, pos.y, pos.z, n, 0, 3.0, 0.0)
        if ok and node and not Util.inBubble(z, node, 20.0) then
            out[#out + 1] = vector3(node.x, node.y, node.z)
            if #out >= count then break end
        end
    end
    return out
end

-- Garage + Spawn eines Teams (einmal pro Gangwar und Seite berechnet)
local function gangwarBase(z)
    local key = z.key .. ':' .. tostring(PvP.side)
    if PvP.gwBase and PvP.gwBase.key == key then return PvP.gwBase end
    local rough = Util.gwSpawnBase(z, PvP.side)
    local spots = roadSpots(rough, z, 10)
    local garage = spots[1] or rough
    PvP.gwBase = { key = key, garage = garage, spots = spots }
    return PvP.gwBase
end
PvP.gangwarBase = gangwarBase

local function gangwarSpawn(z)
    local base = gangwarBase(z)
    if #base.spots < 2 then
        -- keine Straße gefunden (sollte nicht passieren): ebener Boden am groben Punkt,
        -- beim nächsten Spawn wird die Straße nochmal gesucht
        local pos, heading = findSpot(Util.gwSpawnBase(z, PvP.side), 20.0, 'gw:' .. z.key .. ':' .. tostring(PvP.side), z.center)
        base.garage, base.key = pos, nil
        return pos, heading
    end
    local others = otherPlayerPositions()
    local best, bestScore = base.garage, -1
    for i, s in ipairs(base.spots) do
        if i > 1 then                                   -- Punkt 1 ist die Garage
            local score = spotScore(s.x, s.y, others) + math.random() * 4.0
            if score > bestScore then best, bestScore = s, score end
        end
    end
    local pos = vector3(best.x, best.y, best.z + 1.0)
    base.garage = vector3(best.x, best.y, best.z)      -- Garage genau da, wo man spawnt
    return pos, GetHeadingFromVector_2d(z.center.x - pos.x, z.center.y - pos.y)
end

local function spawnPoint()
    if PvP.mode == 'lobby' then return hoodSpawn() end
    local area = PvP.area()
    if not area then return hoodSpawn() end

    if PvP.mode == 'duel' then
        -- fester Startpunkt: Herausforderer = a, Gegner = b (schauen sich an)
        local a = PvP.duel.arena
        local s = PvP.duel.side == 1 and a.a or a.b
        local gz = groundAt(s.x, s.y, s.z + 3.0)
        return vector3(s.x, s.y, (gz or s.z) + 1.0), (s.w or 0.0) + 0.0
    end

    if PvP.mode == 'ffa' then
        local a = Config.Arenas[PvP.arenaIndex]
        if a and a.spawns and #a.spawns > 0 then
            local others = otherPlayerPositions()
            local best, bestScore = a.spawns[1], -1
            for _, s in ipairs(a.spawns) do
                local score = spotScore(s.x, s.y, others) + math.random() * 5.0
                if score > bestScore then best, bestScore = s, score end
            end
            return vector3(best.x, best.y, best.z), (best.w or 0.0) + 0.0
        end
        return findSpot(area.center, area.radius * 0.85, area.key)
    else
        -- Gangwar: Angreifer kommen aus "spawnAngle", Verteidiger von der anderen Seite,
        -- beide auf der Straße außerhalb der Bubble
        return gangwarSpawn(area.zone)
    end
end

-- -----------------------------------------------------------------------
--  Waffen
-- -----------------------------------------------------------------------
local function ownsWeapon(name)
    for _, n in ipairs(PvP.weapons) do
        if n == name then return true end
    end
    return false
end
PvP.ownsWeapon = ownsWeapon

-- Ausgerüsteten Skin auf die Waffe (Farbton oder Bauteil: Tarnmuster / Luxus-Finish)
local function applySkin(ped, w)
    if not HasPedGotWeapon(ped, w.hash, false) then return end
    -- erst alles von anderen Skins dieser Waffe entfernen
    for _, s in ipairs(Skins.byWeapon[w.name] or {}) do
        if s.component then
            local h = GetHashKey(s.component)
            if HasPedGotWeaponComponent(ped, w.hash, h) then RemoveWeaponComponentFromPed(ped, w.hash, h) end
        end
    end
    local skin = PvP.skins[w.name]
    SetPedWeaponTintIndex(ped, w.hash, skin and skin.tint or 0)
    if skin and skin.component then GiveWeaponComponentToPed(ped, w.hash, GetHashKey(skin.component)) end
end
PvP.applySkin = applySkin

-- Alle Aufsätze, die diese Waffe laut Config haben könnte
local function attachmentCandidates(w)
    local out = {}
    for _, s in ipairs(Config.Attachments and Config.Attachments.slots or {}) do
        for _, o in ipairs(s.options or {}) do
            local comp = o.component or (o.suffix and ('COMPONENT_' .. w.name:gsub('^WEAPON_', '') .. o.suffix))
            if comp and DoesWeaponTakeWeaponComponent(w.hash, GetHashKey(comp)) then
                out[#out + 1] = { slot = s.key, slotLabel = s.label, label = o.label, component = comp }
            end
        end
    end
    return out
end
PvP.attachmentCandidates = attachmentCandidates

-- Gewählte Aufsätze anlegen (nur Premium), alles andere aus der Liste abnehmen
local function applyAttachments(ped, w)
    if not HasPedGotWeapon(ped, w.hash, false) then return end
    local premium = PvP.account and PvP.account.premium
    local allowed = premium or not (Config.Attachments and Config.Attachments.premiumOnly)
    local wanted = {}
    local chosen = allowed and PvP.account and PvP.account.attachments and PvP.account.attachments[w.name] or {}
    for _, comp in pairs(chosen) do wanted[comp] = true end
    for _, c in ipairs(w.components or {}) do wanted[c] = true end
    for _, c in ipairs(attachmentCandidates(w)) do
        local h = GetHashKey(c.component)
        local has = HasPedGotWeaponComponent(ped, w.hash, h)
        if wanted[c.component] and not has then
            GiveWeaponComponentToPed(ped, w.hash, h)
        elseif not wanted[c.component] and has then
            RemoveWeaponComponentFromPed(ped, w.hash, h)
        end
    end
end
PvP.applyAttachments = applyAttachments

local function giveWeapon(ped, w)
    GiveWeaponToPed(ped, w.hash, Config.Ammo.amount, false, false)
    if Config.Ammo.infinite then SetPedInfiniteAmmo(ped, true, w.hash) end
    if w.components then
        for _, comp in ipairs(w.components) do
            GiveWeaponComponentToPed(ped, w.hash, GetHashKey(comp))
        end
    end
    applySkin(ped, w)
    applyAttachments(ped, w)
end

-- Aufsätze geändert (F2 → Inventar): sofort an den Waffen in der Hand
RegisterNetEvent('bspvp:attachments', function(list)
    if PvP.account then PvP.account.attachments = type(list) == 'table' and list or {} end
    if PvP.dead then return end
    local ped = PlayerPedId()
    for _, name in ipairs(PvP.weapons) do
        local w = Weapons.get(name)
        if w then applyAttachments(ped, w) end
    end
end)

local function giveLoadout(ped)
    RemoveAllPedWeapons(ped, true)
    if not PvP.armed() then return end
    local equip
    for _, name in ipairs(PvP.weapons) do
        local w = Weapons.get(name)
        if w then
            giveWeapon(ped, w)
            equip = equip or w
            if PvP.lastWeapon and Weapons.toUnsigned(PvP.lastWeapon) == w.uhash then equip = w end
        end
    end
    -- stärkste Waffe zuerst, außer man hatte vorher eine andere in der Hand
    if not PvP.lastWeapon then
        for i = #Weapons.list, 1, -1 do
            if ownsWeapon(Weapons.list[i].name) then equip = Weapons.list[i] break end
        end
    end
    if equip then SetCurrentPedWeapon(ped, equip.hash, true) end
end

local function preparePed(ped)
    SetPedDropsWeaponsWhenDead(ped, false)
    SetCanAttackFriendly(ped, true, true)
    NetworkSetFriendlyFireOption(true)
    SetPedSuffersCriticalHits(ped, false)
    SetPedConfigFlag(ped, 184, true)          -- nicht automatisch den Sitz im Auto wechseln
    ClearPedBloodDamage(ped)
end

local function deathEffect(on)
    if on then
        if AnimpostfxPlay then AnimpostfxPlay('DeathFailMPIn', 0, true)
        elseif StartScreenEffect then StartScreenEffect('DeathFailMPIn', 0, true) end
    else
        if AnimpostfxStop then AnimpostfxStop('DeathFailMPIn')
        elseif StopScreenEffect then StopScreenEffect('DeathFailMPIn') end
    end
end

-- -----------------------------------------------------------------------
--  Spawn
-- -----------------------------------------------------------------------
function PvP.spawn()
    if PvP.spawning then return end
    if PvP.mode ~= 'lobby' and not PvP.inCombat() then return end
    PvP.spawning = true
    Bodyshot.setGuard(false)
    local mode = PvP.mode

    DoScreenFadeOut(300)
    local timeout = GetGameTimer() + 1500
    while not IsScreenFadedOut() and GetGameTimer() < timeout do Wait(0) end

    freezePlayer(true)
    Outfit.apply(PvP.team and PvP.team.outfit or 'silver', PvP.uid, PvP.account and PvP.account.outfit)
    local ped = PlayerPedId()

    -- erst grob hin (Kollision laden), dann den genauen Punkt suchen
    local area = PvP.area()
    local rough = area and area.center or (PvP.hood and PvP.hood.spawn) or Config.Lobby.center
    if area and area.bubble then rough = Util.gwSpawnBase(area.zone, PvP.side) end
    RequestCollisionAtCoord(rough.x, rough.y, rough.z)
    SetEntityCoordsNoOffset(ped, rough.x, rough.y, rough.z + 1.0, false, false, false)
    waitForCollision(ped, 5000)

    local pos, heading = spawnPoint()
    RequestCollisionAtCoord(pos.x, pos.y, pos.z)
    SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false)
    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, heading, true, true, false)

    ped = PlayerPedId()
    SetEntityHeading(ped, heading)
    ClearPedTasksImmediately(ped)
    ClearPlayerWantedLevel(PlayerId())
    waitForCollision(ped, 3000)

    preparePed(ped)
    Bodyshot.applyGameHealth(ped)
    giveLoadout(ped)
    UI.stopCam()
    freezePlayer(false)
    Bodyshot.applyGameHealth(PlayerPedId())
    SetGameplayCamRelativeHeading(0.0)
    deathEffect(false)
    DoScreenFadeIn(500)

    PvP.spawning = false

    -- Während des Spawns kam ein neuer Modus -> gleich nochmal spawnen
    if PvP.respawnPending or PvP.mode ~= mode then
        PvP.respawnPending = false
        PvP.dead = true
        return PvP.spawn()
    end

    PvP.dead = false
    Bodyshot.setGuard(true)
    nui({ type = 'death', show = false })
    TriggerServerEvent('bspvp:spawned')
    TriggerEvent('playerSpawned', { x = pos.x, y = pos.y, z = pos.z, heading = heading })
end

-- Spawnen, auch wenn gerade ein Spawn läuft (dann direkt danach)
function PvP.requestSpawn()
    if PvP.spawning then
        PvP.respawnPending = true
        return
    end
    PvP.spawn()
end

function PvP.teleportInside()
    local ped = PlayerPedId()
    TriggerServerEvent('bspvp:ac:tp')                -- Anticheat: das ist ein erlaubter Teleport
    local pos, heading = spawnPoint()
    DoScreenFadeOut(200)
    local timeout = GetGameTimer() + 1000
    while not IsScreenFadedOut() and GetGameTimer() < timeout do Wait(0) end
    RequestCollisionAtCoord(pos.x, pos.y, pos.z)
    SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false)
    SetEntityHeading(ped, heading)
    waitForCollision(ped, 3000)
    DoScreenFadeIn(300)
end

local function scheduleRespawn(seconds)
    PvP.deathToken = PvP.deathToken + 1
    local token = PvP.deathToken
    SetTimeout(math.floor(seconds * 1000), function()
        if token == PvP.deathToken and PvP.dead and not PvP.spawning then
            PvP.spawn()
        end
    end)
end

local function modeMessage()
    return {
        type = 'mode', mode = PvP.mode, team = PvP.team, uid = PvP.uid,
        place = PvP.placeName(), hood = PvP.hood and PvP.hood.name or nil,
        serverId = GetPlayerServerId(PlayerId()),
    }
end

-- -----------------------------------------------------------------------
--  Server -> Client
-- -----------------------------------------------------------------------
RegisterNetEvent('bspvp:mode', function(data)
    if type(data) ~= 'table' then return end
    local previous = PvP.mode
    PvP.mode = data.mode
    PvP.team = data.team
    PvP.hood = data.hood
    PvP.uid = data.uid or PvP.uid
    PvP.weapons = data.weapons or {}
    PvP.respawn = data.respawn or 3
    PvP.zoneKey = data.zone
    PvP.side = data.side
    PvP.duel = data.duel
    if data.arena then PvP.arenaIndex = data.arena end
    PvP.loggedIn = true
    PvP.dead = true
    PvP.deathToken = PvP.deathToken + 1           -- alte Respawn-Timer verwerfen
    if PvP.mode ~= 'gangwar' then PvP.war = nil end
    if previous ~= PvP.mode or PvP.mode ~= 'lobby' then Garage.forget() end
    PvP.gwBase = nil                               -- Gangwar-Spawn neu suchen

    UI.closeAll()
    Map.refresh()
    if PvP.mode ~= 'lobby' then TriggerEvent('bspvp:playerBlips', {}) end
    nui(modeMessage())
    PvP.requestSpawn()
end)

-- Admin hat die Hood verschoben
RegisterNetEvent('bspvp:hood', function(hood)
    if type(hood) ~= 'table' then return end
    PvP.hood = hood
    Map.refresh()
    nui(modeMessage())
end)

-- Foto vom Charakter des Killers (GTA-Mugshot) für den Todesbildschirm
local headshot = nil
local function releaseHeadshot()
    if headshot then
        UnregisterPedheadshot(headshot)
        headshot = nil
    end
end

local function killerPhoto(killer, token)
    if not killer or not killer.src or killer.avatar then return end   -- Discord-Bild kommt schon vom Server
    CreateThread(function()
        local player = GetPlayerFromServerId(killer.src)
        local ped = player ~= -1 and GetPlayerPed(player) or 0
        if ped == 0 or not DoesEntityExist(ped) then return end
        releaseHeadshot()
        local handle = RegisterPedheadshotTransparent and RegisterPedheadshotTransparent(ped) or RegisterPedheadshot(ped)
        headshot = handle
        local timeout = GetGameTimer() + 3000
        while not (IsPedheadshotReady(handle) and IsPedheadshotValid(handle)) and GetGameTimer() < timeout do Wait(50) end
        if token ~= PvP.deathToken or headshot ~= handle or not IsPedheadshotReady(handle) then return end
        local txd = GetPedheadshotTxdString(handle)
        nui({ type = 'deathPhoto', url = ('https://nui-img/%s/%s'):format(txd, txd) })
    end)
end

RegisterNetEvent('bspvp:died', function(info)
    info = info or {}
    if not PvP.dead then
        PvP.dead = true
        local ped = PlayerPedId()
        if not IsEntityDead(ped) then SetEntityHealth(ped, 0) end
    end
    Bodyshot.setGuard(false)
    deathEffect(true)
    if info.duel then
        -- Duell: die nächste Runde stellt beide neu hin (kein eigener Respawn)
        nui({ type = 'death', show = true, killer = info.killer, weapon = info.weapon, cause = info.cause, duel = true })
        killerPhoto(info.killer, PvP.deathToken)
        return
    end
    local seconds = info.respawn or PvP.respawn
    nui({ type = 'death', show = true, killer = info.killer, weapon = info.weapon, cause = info.cause, seconds = seconds })
    scheduleRespawn(seconds)
    killerPhoto(info.killer, PvP.deathToken)
end)

RegisterNetEvent('bspvp:protection', function(on, seconds)
    PvP.protectToken = PvP.protectToken + 1
    local token = PvP.protectToken
    PvP.protected = on and true or false
    if not on then
        ResetEntityAlpha(PlayerPedId())
        nui({ type = 'protect', show = false })
        return
    end
    SetEntityAlpha(PlayerPedId(), 170, false)
    nui({ type = 'protect', show = true, seconds = seconds })
    CreateThread(function()
        local endAt = GetGameTimer() + (seconds or 3) * 1000
        while token == PvP.protectToken and GetGameTimer() < endAt do
            if IsPedShooting(PlayerPedId()) then
                TriggerServerEvent('bspvp:endProtection')
                break
            end
            Wait(0)
        end
        if token == PvP.protectToken then
            PvP.protected = false
            ResetEntityAlpha(PlayerPedId())
            nui({ type = 'protect', show = false })
        end
    end)
end)

RegisterNetEvent('bspvp:refill', function()
    local ped = PlayerPedId()
    for _, name in ipairs(PvP.weapons) do
        local w = Weapons.get(name)
        if w and HasPedGotWeapon(ped, w.hash, false) then
            SetPedAmmo(ped, w.hash, Config.Ammo.amount)
            local maxClip = GetMaxAmmoInClip(ped, w.hash, true)
            if maxClip and maxClip > 0 then SetAmmoInClip(ped, w.hash, maxClip) end
        end
    end
end)

RegisterNetEvent('bspvp:giveWeapon', function(name)
    local w = Weapons.get(name)
    if not w then return end
    if not ownsWeapon(w.name) then PvP.weapons[#PvP.weapons + 1] = w.name end
    if not PvP.dead and PvP.armed() then
        giveWeapon(PlayerPedId(), w)
    end
end)

-- Inventar (F2): Waffe direkt in die Hand nehmen
function PvP.holdWeapon(name)
    local w = Weapons.get(name)
    if not w or PvP.dead or not PvP.armed() or not ownsWeapon(w.name) then return end
    local ped = PlayerPedId()
    if not HasPedGotWeapon(ped, w.hash, false) then giveWeapon(ped, w) end
    SetCurrentPedWeapon(ped, w.hash, true)
    PvP.lastWeapon = w.hash
end

RegisterNetEvent('bspvp:account', function(view)
    PvP.account = view
    nui({ type = 'account', account = view })
end)

RegisterNetEvent('bspvp:killfeed', function(entry) nui({ type = 'killfeed', entry = entry }) end)
RegisterNetEvent('bspvp:announce', function(text) nui({ type = 'announce', text = text }) end)
RegisterNetEvent('bspvp:notify', function(kind, text) nui({ type = 'notify', kind = kind, text = text }) end)

-- -----------------------------------------------------------------------
--  Start
-- -----------------------------------------------------------------------
local function disableSpawnmanager()
    if GetResourceState('spawnmanager') == 'started' then
        pcall(function() exports.spawnmanager:setAutoSpawn(false) end)
    end
end

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(250) end
    disableSpawnmanager()

    SetMaxWantedLevel(0)
    SetPoliceIgnorePlayer(PlayerId(), true)
    for i = 1, 15 do EnableDispatchService(i, false) end
    SetCreateRandomCops(false)
    SetCreateRandomCopsNotOnScenarios(false)
    SetCreateRandomCopsOnScenarios(false)
    SetGarbageTrucks(false)
    SetRandomBoats(false)
    DistantCopCarSirens(false)
    SetAudioFlag('PoliceScannerDisabled', true)

    TriggerServerEvent('bspvp:ready')
end)

AddEventHandler('onClientMapStart', function()
    SetTimeout(1000, disableSpawnmanager)
end)

-- -----------------------------------------------------------------------
--  Jede Frame: NPCs, Nahkampf, Hood = kein Schießen, Zonen-Wand
-- -----------------------------------------------------------------------
CreateThread(function()
    while true do
        if Config.World.disableNPCs then
            SetPedDensityMultiplierThisFrame(0.0)
            SetScenarioPedDensityMultiplierThisFrame(0.0, 0.0)
            SetVehicleDensityMultiplierThisFrame(0.0)
            SetRandomVehicleDensityMultiplierThisFrame(0.0)
            SetParkedVehicleDensityMultiplierThisFrame(0.0)
        end

        if Config.DisableMelee or PvP.mode == 'lobby' then
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 263, true)
            DisableControlAction(0, 264, true)
        end
        if PvP.mode == 'lobby' and not Config.HoodCombat then
            DisablePlayerFiring(PlayerId(), true)        -- Hood = Safezone (nur wenn HoodCombat aus ist)
        elseif PvP.mode == 'duel' and GetGameTimer() < PvP.duelFreezeUntil then
            DisablePlayerFiring(PlayerId(), true)        -- Duell-Countdown: stillhalten
            for _, c in ipairs({ 21, 22, 24, 25, 30, 31, 32, 33, 34, 35, 44, 140, 141, 142 }) do DisableControlAction(0, c, true) end
        end

        local area = PvP.inCombat() and PvP.area()
        if area and area.bubble then
            -- Gangwar-Bubble: Kuppel auf der Straße (Vorbereitung blau, Kampf rot)
            local c = area.center
            local fight = PvP.war and PvP.war.phase == 'fight'
            local r, g, b = 47, 128, 255
            if fight then r, g, b = 242, 61, 79 end
            DrawMarker(28, c.x, c.y, c.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                area.radius, area.radius, area.radius, r, g, b, 45,
                false, false, 2, false, nil, nil, false)
            DrawMarker(1, c.x, c.y, c.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                area.radius * 2.0, area.radius * 2.0, 1.5, r, g, b, 90,
                false, false, 2, false, nil, nil, false)
        elseif area then
            local z = (PvP.baseZ[area.key] or area.center.z) - 20.0
            DrawMarker(1, area.center.x, area.center.y, z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                area.radius * 2.0, area.radius * 2.0, 60.0, 242, 61, 79, 40,
                false, false, 2, false, nil, nil, false)
        end
        Wait(0)
    end
end)

-- -----------------------------------------------------------------------
--  Alle 250 ms: Tod erkennen, Zone, nur gekaufte Waffen
-- -----------------------------------------------------------------------
CreateThread(function()
    local outsideSince
    while true do
        Wait(250)
        local ped = PlayerPedId()
        local active = PvP.loggedIn and not PvP.dead and not PvP.spawning
            and (PvP.mode == 'lobby' or PvP.inCombat())

        if active then
            if IsEntityDead(ped) then
                PvP.dead = true
                Bodyshot.setGuard(false)
                TriggerServerEvent('bspvp:envDeath')
                if PvP.mode ~= 'duel' then scheduleRespawn(PvP.respawn + 3) end   -- Sicherheitsnetz
            else
                local area = PvP.area()
                if area then
                    local p = GetEntityCoords(ped)
                    local dx, dy = p.x - area.center.x, p.y - area.center.y
                    local limit = area.boundary or area.radius      -- Gangwar: ganzes Spielfeld inkl. Spawns
                    if dx * dx + dy * dy > limit * limit then
                        outsideSince = outsideSince or GetGameTimer()
                        local left = (Config.OutOfZoneSeconds or 5) - (GetGameTimer() - outsideSince) / 1000
                        if left <= 0 then
                            outsideSince = nil
                            nui({ type = 'zone', show = false })
                            PvP.teleportInside()
                        else
                            nui({ type = 'zone', show = true, seconds = math.ceil(left) })
                        end
                    elseif outsideSince then
                        outsideSince = nil
                        nui({ type = 'zone', show = false })
                    end
                elseif outsideSince then
                    outsideSince = nil
                    nui({ type = 'zone', show = false })
                end

                -- nur gekaufte Langwaffen (überall, wo man bewaffnet ist)
                local current = GetSelectedPedWeapon(ped)
                local w = Weapons.fromHash(current)
                if w and PvP.armed() and ownsWeapon(w.name) then
                    PvP.lastWeapon = current
                elseif current ~= UNARMED and Config.BlockOtherWeapons then
                    RemoveWeaponFromPed(ped, current)
                    SetCurrentPedWeapon(ped, UNARMED, true)
                end
            end
        elseif outsideSince then
            outsideSince = nil
            nui({ type = 'zone', show = false })
        end
    end
end)

-- -----------------------------------------------------------------------
--  Jede Sekunde: Welt-Einstellungen
-- -----------------------------------------------------------------------
CreateThread(function()
    local tick = 0
    while true do
        local player = PlayerId()
        ClearPlayerWantedLevel(player)
        SetPlayerHealthRechargeMultiplier(player, 0.0)
        DisablePlayerVehicleRewards(player)
        if Config.World.time then
            NetworkOverrideClockTime(Config.World.time[1] or 12, Config.World.time[2] or 0, 0)
        end
        if Config.World.weather and tick % 5 == 0 then
            local wtr = Config.World.weather
            ClearOverrideWeather()
            ClearWeatherTypePersist()
            SetWeatherTypePersist(wtr)
            SetWeatherTypeNow(wtr)
            SetWeatherTypeNowPersist(wtr)
        end
        tick = tick + 1
        Wait(1000)
    end
end)

-- -----------------------------------------------------------------------
--  Befehle
-- -----------------------------------------------------------------------
RegisterCommand('pvpcoords', function()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local line = ('vector4(%.2f, %.2f, %.2f, %.1f),'):format(c.x, c.y, c.z, GetEntityHeading(ped))
    print(line)
    TriggerEvent('chat:addMessage', { color = { 14, 165, 255 }, args = { 'Koordinaten', line } })
end, false)

CreateThread(function()
    Wait(2000)
    local s = function(cmd, help, params) TriggerEvent('chat:addSuggestion', cmd, help, params) end
    s('/hood', 'Zurück zu deiner Hood')
    s('/kill', 'Neu spawnen (zählt als Tod)')
    s('/t', 'Nachricht an dein Team', { { name = 'text', help = 'Nachricht' } })
    s('/id', 'Deine User-ID')
    s('/stats', 'Statistik', { { name = 'id', help = 'User-ID (optional)' } })
    s('/top', 'Top 10 nach Kills')
    s('/pvpcoords', 'Position für eigene Spawnpunkte')
    s('/admin', 'Admin: Admin-Menü')
    s('/heal', 'Admin: heilen', { { name = 'id', help = 'User-ID (optional)' } })
    s('/givemoney', 'Admin: Geld geben', { { name = 'id', help = 'User-ID' }, { name = 'betrag', help = 'Betrag' } })
    s('/givexp', 'Admin: XP geben', { { name = 'id', help = 'User-ID' }, { name = 'xp', help = 'XP' } })
    s('/premium', 'Admin: Premium-Pass', { { name = 'id', help = 'User-ID' }, { name = '0', help = '0 = wegnehmen' } })
    s('/setzone', 'Admin: Gebiet setzen', { { name = 'gebiet', help = 'z. B. hafen' }, { name = 'team', help = 'Gang-ID, p<Nr> oder frei' } })
    s('/endwar', 'Admin: Gangwar beenden', { { name = 'gebiet', help = 'z. B. hafen' } })
    s('/sethood', 'Admin: Hood-Punkt setzen', { { name = 'was', help = 'spawn, garage, car oder reset' }, { name = 'team', help = 'Gang-ID oder p<Nr> (optional)' } })
    s('/kick', 'Admin: Spieler kicken', { { name = 'id', help = 'User-ID' }, { name = 'grund', help = 'Grund' } })
    s('/ban', 'Admin: Spieler bannen', { { name = 'id', help = 'User-ID' }, { name = 'stunden', help = '0 = für immer' }, { name = 'grund', help = 'Grund' } })
    s('/unban', 'Admin: Bann aufheben', { { name = 'id', help = 'User-ID' } })
    s('/mute', 'Admin: stummschalten', { { name = 'id', help = 'User-ID' }, { name = 'minuten', help = '0 = aufheben' } })
    s('/announce', 'Admin: Ankündigung', { { name = 'text', help = 'Text' } })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    deathEffect(false)
    releaseHeadshot()
    ResetEntityAlpha(PlayerPedId())
end)
