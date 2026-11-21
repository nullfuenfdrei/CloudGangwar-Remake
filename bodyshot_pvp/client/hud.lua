-- =======================================================================
--  Client: HUD-Daten (Munition, Online, Spielzeit-Bonus), GTA-HUD-Teile aus,
--  Hinweise unten in der Mitte ("E  Garage"), HUD im Pausenmenü verstecken
-- =======================================================================

HUD = { prompts = {}, order = 0 }

local function nui(data) SendNUIMessage(data) end

function HUD.notify(kind, text)
    nui({ type = 'notify', kind = kind, text = text })
end

-- Hinweis an/aus. Mehrere gleichzeitig -> der neueste wird gezeigt.
function HUD.prompt(id, show, key, text)
    if show then
        HUD.order = HUD.order + 1
        HUD.prompts[id] = { key = key, text = text, n = HUD.order }
    elseif HUD.prompts[id] then
        HUD.prompts[id] = nil
    else
        return
    end
    local top
    for _, v in pairs(HUD.prompts) do
        if not top or v.n > top.n then top = v end
    end
    nui({ type = 'prompt', show = top ~= nil, key = top and top.key or nil, text = top and top.text or nil })
end

RegisterNetEvent('bspvp:hud', function(data)
    if type(data) == 'table' then nui({ type = 'hudData', data = data }) end
end)

-- -----------------------------------------------------------------------
--  Jede Frame: Fahndungssterne, GTA-Geld, Orts-/Fahrzeugnamen und das
--  Waffen-Symbol oben rechts aus (dort sitzt jetzt unser Statistik-Block)
-- -----------------------------------------------------------------------
CreateThread(function()
    while true do
        HideHudComponentThisFrame(1)    -- Fahndung
        HideHudComponentThisFrame(2)    -- Waffe + Munition (eigene Anzeige unten rechts)
        HideHudComponentThisFrame(3)    -- Bargeld
        HideHudComponentThisFrame(4)    -- MP-Geld
        HideHudComponentThisFrame(6)    -- Fahrzeugname
        HideHudComponentThisFrame(7)    -- Gebiet
        HideHudComponentThisFrame(8)    -- Fahrzeugklasse
        HideHudComponentThisFrame(9)    -- Straße
        HideHudComponentThisFrame(13)   -- Geld-Änderung
        if not PvP.loggedIn or PvP.mode == 'login' or PvP.mode == 'select' then
            HideHudAndRadarThisFrame()
        end
        Wait(0)
    end
end)

-- -----------------------------------------------------------------------
--  Munition (nur im Kampf) – wird nur bei Änderungen geschickt
-- -----------------------------------------------------------------------
CreateThread(function()
    local last = ''
    while true do
        local sleep = 250
        local msg
        if PvP.loggedIn and not PvP.dead and PvP.armed() then
            local ped = PlayerPedId()
            local weapon = GetSelectedPedWeapon(ped)
            local w = Weapons.fromHash(weapon)
            if w then
                local _, clip = GetAmmoInClip(ped, weapon)
                local total = GetAmmoInPedWeapon(ped, weapon)
                msg = {
                    show = true, name = w.label, weapon = w.name,
                    clip = clip or 0, maxClip = GetMaxAmmoInClip(ped, weapon, true) or 0,
                    reserve = Config.Ammo.infinite and -1 or math.max(0, (total or 0) - (clip or 0)),
                    reloading = IsPedReloading(ped),
                }
                sleep = 80
            end
        end
        local key = msg and (msg.weapon .. ':' .. msg.clip .. ':' .. msg.reserve .. ':' .. tostring(msg.reloading)) or 'off'
        if key ~= last then
            last = key
            nui({ type = 'ammo', ammo = msg or { show = false } })
        end
        Wait(sleep)
    end
end)

-- -----------------------------------------------------------------------
--  Pausenmenü / große Karte: HUD ausblenden
-- -----------------------------------------------------------------------
CreateThread(function()
    local hidden = false
    while true do
        local now = IsPauseMenuActive()
        if now ~= hidden then
            hidden = now
            nui({ type = 'hudVisible', show = not now })
        end
        Wait(250)
    end
end)
