-- =======================================================================
--  Client: Weste (G) & Medkit (H) ziehen – Balken unten mit Prozent
--  Der Server zählt die Items und misst die Zeit selbst mit.
-- =======================================================================

Items = { using = nil }

local function nui(data) SendNUIMessage(data) end

local ANIMS = {
    vest   = { dict = 'clothingtie', anim = 'try_tie_negative_a' },
    medkit = { dict = 'mp_arresting', anim = 'a_uncuff' },
}
local BLOCK = { 24, 25, 37, 44, 140, 141, 142, 257, 263, 264 }   -- schießen, zielen, Waffenrad, Deckung, Nahkampf

local function stopAnim()
    local a = Items.using and ANIMS[Items.using.kind]
    if a and IsEntityPlayingAnim(PlayerPedId(), a.dict, a.anim, 3) then StopAnimTask(PlayerPedId(), a.dict, a.anim, 2.0) end
end

function Items.cancel(reason)
    if not Items.using then return end
    stopAnim()
    Items.using = nil
    nui({ type = 'itemBar', show = false })
    TriggerServerEvent('bspvp:item:cancel')
    if reason then HUD.notify('error', reason) end
end

local function use(kind)
    if not PvP.loggedIn or PvP.dead or PvP.spawning or UI.screen ~= nil then return end
    if Items.using then
        if Items.using.kind == kind then Items.cancel() end      -- nochmal drücken = abbrechen
        return
    end
    if Emotes and Emotes.current then Emotes.stop() end
    TriggerServerEvent('bspvp:item:start', kind)
end

RegisterCommand('gwvest', function() use('vest') end, false)
RegisterCommand('gwmedkit', function() use('medkit') end, false)
RegisterCommand('weste', function() use('vest') end, false)
RegisterCommand('medkit', function() use('medkit') end, false)
RegisterKeyMapping('gwvest', 'Weste ziehen', 'keyboard', Config.Items.vest.key or 'G')
RegisterKeyMapping('gwmedkit', 'Medkit benutzen', 'keyboard', Config.Items.medkit.key or 'H')

RegisterNetEvent('bspvp:item:started', function(d)
    if type(d) ~= 'table' or PvP.dead then return end
    local ms = math.floor((d.seconds or 3.5) * 1000)
    local token = d.token
    Items.using = { kind = d.kind, token = token, endsAt = GetGameTimer() + ms }
    nui({ type = 'itemBar', show = true, kind = d.kind, label = d.kind == 'vest' and 'Ziehe Weste' or 'Benutze Medkit', seconds = d.seconds })

    CreateThread(function()
        local ped = PlayerPedId()
        local a = ANIMS[d.kind]
        if a and not IsPedInAnyVehicle(ped, false) and DoesAnimDictExist(a.dict) then
            RequestAnimDict(a.dict)
            local timeout = GetGameTimer() + 1500
            while not HasAnimDictLoaded(a.dict) and GetGameTimer() < timeout do Wait(0) end
            if HasAnimDictLoaded(a.dict) then
                TaskPlayAnim(ped, a.dict, a.anim, 3.0, 3.0, ms, 49, 0, false, false, false)   -- Oberkörper, man kann laufen
                RemoveAnimDict(a.dict)
            end
        end
        while Items.using and Items.using.token == token do
            if PvP.dead then Items.cancel() break end
            DisableControlAction(0, 21, true)                  -- nicht sprinten
            for _, c in ipairs(BLOCK) do DisableControlAction(0, c, true) end
            if GetGameTimer() >= Items.using.endsAt then
                stopAnim()
                Items.using = nil
                nui({ type = 'itemBar', show = false })
                TriggerServerEvent('bspvp:item:finish', token)
                break
            end
            Wait(0)
        end
    end)
end)

-- Getroffen = abbrechen (der Server prüft das auch)
RegisterNetEvent('bspvp:hit', function()
    if Items.using then Items.cancel('Abgebrochen – du wurdest getroffen.') end
end)

RegisterNetEvent('bspvp:mode', function()
    if Items.using then Items.cancel() end
end)

-- Anzeige der Anzahl unten rechts (aus dem Account)
CreateThread(function()
    local last = ''
    while true do
        Wait(500)
        local acc = PvP.account
        local items = acc and acc.items or {}
        local show = PvP.loggedIn and PvP.armed() and not PvP.dead
        local unl = Config.Items.unlimited == true                 -- -1 = unendlich
        local vest, medkit = unl and -1 or (items.vest or 0), unl and -1 or (items.medkit or 0)
        local key = show and (vest .. ':' .. medkit) or 'off'
        if key ~= last then
            last = key
            nui({ type = 'itemCounts', show = show, vest = vest, medkit = medkit,
                  vestKey = Config.Items.vest.key or 'G', medkitKey = Config.Items.medkit.key or 'H' })
        end
    end
end)
