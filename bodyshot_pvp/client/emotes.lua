-- =======================================================================
--  Client: Emotes & Tänze (/e <name>, Taste K = Emote-Menü),
--  Admin-Trolls, Admin-Teleport und Anticheat-Herzschlag
-- =======================================================================

Emotes = { current = nil, forcedUntil = 0 }

local function nui(data) SendNUIMessage(data) end
local UNARMED = GetHashKey('WEAPON_UNARMED')
local MOVE_KEYS = { 21, 22, 24, 25, 30, 31, 32, 33, 34, 35, 44 }

local function allowed()
    if not (Config.Emotes and Config.Emotes.enabled ~= false) then return false, 'Emotes sind ausgeschaltet.' end
    if not PvP.loggedIn or PvP.dead or PvP.spawning then return false, 'Gerade nicht möglich.' end
    if PvP.mode ~= 'lobby' and not (Config.Emotes.inCombat and PvP.inCombat()) then
        return false, 'Emotes gehen an deiner Hood.'
    end
    if IsPedInAnyVehicle(PlayerPedId(), false) then return false, 'Steig zuerst aus dem Fahrzeug aus.' end
    return true
end

function Emotes.stop()
    if not Emotes.current then return end
    Emotes.current = nil
    ClearPedTasks(PlayerPedId())
end

local function loadDict(dict)
    if not DoesAnimDictExist(dict) then return false end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(0) end
    return HasAnimDictLoaded(dict)
end

-- force = von einem Admin-Troll (geht überall, Bewegen bricht nicht ab)
function Emotes.play(name, force)
    name = string.lower(tostring(name or ''))
    if name == '' or name == 'stop' or name == 'c' or name == 'cancel' then return Emotes.stop() end
    local e = EmoteByName[name]
    if not e then return HUD.notify('error', ('Emote "%s" gibt es nicht. Alle Emotes: Taste %s'):format(name, Config.Emotes.key or 'K')) end
    if not force then
        local ok, why = allowed()
        if not ok then return HUD.notify('error', why) end
    end
    CreateThread(function()
        if not loadDict(e.dict) then
            return HUD.notify('error', ('Die Animation "%s" fehlt auf dem Server (stream-Ordner).'):format(e.label))
        end
        local ped = PlayerPedId()
        SetCurrentPedWeapon(ped, UNARMED, true)
        local flag = e.loop and 1 or 0
        if e.upper then flag = flag + 48 end
        TaskPlayAnim(ped, e.dict, e.anim, 3.0, 3.0, -1, flag, 0, false, false, false)
        RemoveAnimDict(e.dict)
        local token = {}
        Emotes.current = { name = e.name, token = token, dict = e.dict, anim = e.anim }
        Wait(400)
        -- Abbrechen: bewegen, springen, zielen, schießen, sterben, Modus wechseln
        while Emotes.current and Emotes.current.token == token do
            if PvP.dead or not PvP.loggedIn then Emotes.current = nil break end
            if GetGameTimer() >= Emotes.forcedUntil then
                for _, c in ipairs(MOVE_KEYS) do
                    if IsControlPressed(0, c) or IsDisabledControlPressed(0, c) then Emotes.stop() break end
                end
            else
                for _, c in ipairs(MOVE_KEYS) do DisableControlAction(0, c, true) end
            end
            if Emotes.current and not IsEntityPlayingAnim(PlayerPedId(), e.dict, e.anim, 3) then
                Emotes.current = nil
            end
            Wait(0)
        end
    end)
end

RegisterCommand('e', function(_, args) Emotes.play(args[1]) end, false)
RegisterCommand('emote', function(_, args) Emotes.play(args[1]) end, false)

-- Taste K: Emote-Seite im F2-Menü
RegisterCommand('gwemotes', function()
    if UI.screen ~= nil then return end
    if Emotes.current then return Emotes.stop() end
    UI.menuPage = 'emotes'
    UI.openMenu()
end, false)
RegisterKeyMapping('gwemotes', 'Emotes & Tänze', 'keyboard', Config.Emotes and Config.Emotes.key or 'K')

CreateThread(function()
    Wait(2500)
    TriggerEvent('chat:addSuggestion', '/e', 'Emote oder Tanz abspielen', { { name = 'name', help = 'floss, takel – oder stop' } })
    TriggerEvent('chat:addSuggestion', '/emotes', 'Alle Emotes und Tänze')
end)

-- -----------------------------------------------------------------------
--  Admin-Trolls (kommen nur vom Server, nach Admin-Prüfung)
--  Niemand verliert dabei Leben: kurz unverwundbar, kein Fallschaden.
-- -----------------------------------------------------------------------
local function safeFor(ms)
    local ped = PlayerPedId()
    Bodyshot.ignoreEnvUntil = GetGameTimer() + ms
    SetEntityInvincible(ped, true)
    SetTimeout(ms, function() SetEntityInvincible(PlayerPedId(), false) end)
end

local TROLL = {}
TROLL.launch = function(ped)
    safeFor(9000)
    SetPedToRagdoll(ped, 5000, 5000, 0, false, false, false)
    ApplyForceToEntity(ped, 1, 0.0, 0.0, 45.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
end
TROLL.slap = function(ped)
    safeFor(5000)
    SetPedToRagdoll(ped, 2500, 2500, 0, false, false, false)
    ApplyForceToEntity(ped, 1, math.random(-12, 12) + 0.0, math.random(-12, 12) + 0.0, 6.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
    PlaySoundFrontend(-1, 'Hit_1', 'LONG_PLAYER_SWITCH_SOUNDS', true)
end
TROLL.ragdoll = function(ped)
    safeFor(6000)
    SetPedToRagdoll(ped, 5000, 5000, 0, false, false, false)
end
TROLL.spin = function()
    CreateThread(function()
        local endAt = GetGameTimer() + 5000
        while GetGameTimer() < endAt do
            local ped = PlayerPedId()
            SetEntityHeading(ped, (GetEntityHeading(ped) + 18.0) % 360.0)
            Wait(0)
        end
    end)
end
TROLL.drunk = function(ped)
    RequestAnimSet('move_m@drunk@verydrunk')
    local timeout = GetGameTimer() + 2000
    while not HasAnimSetLoaded('move_m@drunk@verydrunk') and GetGameTimer() < timeout do Wait(0) end
    SetPedMovementClipset(ped, 'move_m@drunk@verydrunk', 1.0)
    SetPedIsDrunk(ped, true)
    SetTimecycleModifier('spectator5')
    ShakeGameplayCam('DRUNK_SHAKE', 2.0)
    SetTimeout(30000, function()
        local p = PlayerPedId()
        ResetPedMovementClipset(p, 1.0)
        SetPedIsDrunk(p, false)
        ClearTimecycleModifier()
        StopGameplayCamShaking(true)
    end)
end
TROLL.freeze = function(ped)
    FreezeEntityPosition(ped, true)
    SetTimeout(10000, function() FreezeEntityPosition(PlayerPedId(), false) end)
end
TROLL.shake = function()
    ShakeGameplayCam('LARGE_EXPLOSION_SHAKE', 1.5)
    SetTimeout(6000, function() StopGameplayCamShaking(true) end)
end
TROLL.blind = function()
    DoScreenFadeOut(400)
    SetTimeout(5000, function() DoScreenFadeIn(800) end)
end
TROLL.dance = function()
    Emotes.forcedUntil = GetGameTimer() + 10000
    Emotes.play('floss', true)
    SetTimeout(10000, function() if Emotes.current then Emotes.stop() end end)
end
TROLL.clown = function()
    AnimpostfxPlay('DrugsMichaelAliensFight', 0, true)
    SetTimeout(15000, function() AnimpostfxStop('DrugsMichaelAliensFight') end)
end
TROLL.eject = function(ped)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then
        safeFor(5000)
        TaskLeaveVehicle(ped, veh, 4160)
    end
end
TROLL.flip = function(ped)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 and NetworkHasControlOfEntity(veh) then
        safeFor(5000)
        local rot = GetEntityRotation(veh, 2)
        SetEntityRotation(veh, 180.0, 0.0, rot.z, 2, true)
    end
end

RegisterNetEvent('bspvp:troll', function(kind)
    local fn = TROLL[tostring(kind)]
    if fn and PvP.loggedIn and not PvP.dead then fn(PlayerPedId()) end
end)

-- Admin-Teleport (Goto / Bring)
RegisterNetEvent('bspvp:admin:teleport', function(pos)
    if type(pos) ~= 'table' or not pos.x then return end
    CreateThread(function()
        local ped = PlayerPedId()
        RequestCollisionAtCoord(pos.x, pos.y, pos.z)
        SetEntityCoords(ped, pos.x, pos.y, pos.z + 0.5, false, false, false, false)
        local timeout = GetGameTimer() + 3000
        while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do Wait(0) end
    end)
end)

-- -----------------------------------------------------------------------
--  Anticheat: Lebenszeichen an den Server (fehlt es, wurde das Skript gestoppt)
-- -----------------------------------------------------------------------
local function resourceList()
    local out = {}
    for i = 0, GetNumResources() - 1 do
        local name = GetResourceByFindIndex(i)
        if name and GetResourceState(name) == 'started' then out[#out + 1] = name end
    end
    return out
end

CreateThread(function()
    while true do
        Wait(20000)
        if PvP.loggedIn then TriggerServerEvent('bspvp:ac:beat', resourceList()) end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if Emotes.current then ClearPedTasks(PlayerPedId()) end
    ClearTimecycleModifier()
    StopGameplayCamShaking(true)
    AnimpostfxStop('DrugsMichaelAliensFight')
end)
