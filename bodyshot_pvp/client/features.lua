-- =======================================================================
--  Client: Neu in v4 – Skins, Cases, Tagesmissionen, 1v1-Duelle, Kopfgeld
-- =======================================================================

local function nui(data) SendNUIMessage(data) end

-- -----------------------------------------------------------------------
--  Skins: ausgerüstete Lackierungen
-- -----------------------------------------------------------------------
RegisterNetEvent('bspvp:skins', function(list)
    PvP.skins = type(list) == 'table' and list or {}
    -- gerade bewaffnet? Dann sofort neu lackieren
    local ped = PlayerPedId()
    if not PvP.dead and PvP.armed() then
        for _, name in ipairs(PvP.weapons or {}) do
            local w = Weapons.get(name)
            if w then PvP.applySkin(ped, w) end
        end
    end
end)

-- -----------------------------------------------------------------------
--  Cases & Missionen & Kopfgeld: nur an die NUI weiterreichen
-- -----------------------------------------------------------------------
RegisterNetEvent('bspvp:caseResult', function(data)
    if type(data) == 'table' then nui({ type = 'caseResult', data = data }) end
end)

RegisterNetEvent('bspvp:missionDone', function(data)
    if type(data) == 'table' then nui({ type = 'missionDone', data = data }) end
end)

RegisterNetEvent('bspvp:bountyClaimed', function(data)
    if type(data) == 'table' then nui({ type = 'bountyClaimed', data = data }) end
end)

-- -----------------------------------------------------------------------
--  1v1-Duelle
-- -----------------------------------------------------------------------
local invite = nil      -- offene Herausforderung (für Y / X)

RegisterNetEvent('bspvp:duelInvite', function(data)
    if type(data) ~= 'table' then
        invite = nil
        nui({ type = 'duelInvite', show = false })
        return
    end
    invite = data
    invite.expires = GetGameTimer() + (data.seconds or 30) * 1000
    nui({ type = 'duelInvite', show = true, data = data, keys = { accept = Config.Keys.duelAccept or 'Y', decline = Config.Keys.duelDecline or 'X' } })
    PlaySoundFrontend(-1, 'CHALLENGE_UNLOCKED', 'HUD_AWARDS', true)
end)

local function respond(accept)
    if not invite or GetGameTimer() > invite.expires then return end
    invite = nil
    nui({ type = 'duelInvite', show = false })
    TriggerServerEvent('bspvp:duelRespond', accept)
end

RegisterCommand('+gwduelyes', function() respond(true) end, false)
RegisterCommand('-gwduelyes', function() end, false)
RegisterCommand('+gwduelno', function() respond(false) end, false)
RegisterCommand('-gwduelno', function() end, false)
RegisterKeyMapping('+gwduelyes', 'Duell annehmen', 'keyboard', Config.Keys.duelAccept or 'Y')
RegisterKeyMapping('+gwduelno', 'Duell ablehnen', 'keyboard', Config.Keys.duelDecline or 'X')

RegisterNUICallback('duelRespond', function(data, cb)
    respond(data and data.accept == true)
    cb({})
end)

RegisterNetEvent('bspvp:duelState', function(data)
    if type(data) ~= 'table' then return end
    if data.phase == 'countdown' then
        PvP.duelFreezeUntil = GetGameTimer() + math.floor((data.startsIn or 5) * 1000)
    elseif data.phase == 'fight' then
        PvP.duelFreezeUntil = 0
    end
    nui({ type = 'duel', data = data })
end)

RegisterNetEvent('bspvp:duelEnd', function(data)
    PvP.duelFreezeUntil = 0
    nui({ type = 'duelEnd', data = data })
    PlaySoundFrontend(-1, (data and data.won) and 'RACE_PLACED' or 'LOSER', 'HUD_AWARDS', true)
end)

-- -----------------------------------------------------------------------
--  Kopfgeld über dem Kopf (gleiche Welt, bis 80 m, Sichtlinie)
-- -----------------------------------------------------------------------
local function draw3dText(x, y, z, text, r, g, b)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.0, 0.34)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(r, g, b, 235)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
end

CreateThread(function()
    local marked = {}
    local nextScan = 0
    while true do
        local sleep = 500
        if Config.Bounty and Config.Bounty.enabled and Config.Bounty.marker and PvP.loggedIn and (PvP.mode == 'ffa' or PvP.mode == 'gangwar') then
            local now = GetGameTimer()
            if now >= nextScan then
                nextScan = now + 500
                marked = {}
                local me = PlayerPedId()
                local myPos = GetEntityCoords(me)
                for _, pid in ipairs(GetActivePlayers()) do
                    if pid ~= PlayerId() then
                        local amount = Player(GetPlayerServerId(pid)).state.gwBounty
                        if amount and amount > 0 then
                            local ped = GetPlayerPed(pid)
                            if ped ~= 0 and not IsEntityDead(ped) and #(GetEntityCoords(ped) - myPos) < 80.0
                                and HasEntityClearLosToEntity(me, ped, 17) then
                                marked[#marked + 1] = { ped = ped, text = ('$%s'):format(Util.formatMoney(amount)) }
                            end
                        end
                    end
                end
            end
            if #marked > 0 then
                sleep = 0
                for _, m in ipairs(marked) do
                    if DoesEntityExist(m.ped) then
                        local c = GetPedBoneCoords(m.ped, 31086, 0.0, 0.0, 0.0)   -- Kopf
                        draw3dText(c.x, c.y, c.z + 0.42, '~r~KOPFGELD~s~  ' .. m.text, 255, 255, 255)
                    end
                end
            end
        end
        Wait(sleep)
    end
end)
