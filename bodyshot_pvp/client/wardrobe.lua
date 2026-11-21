-- =======================================================================
--  Client: Kleiderschrank an der Hood (/kleidung oder F2 → Kleiderschrank)
--  Live-Vorschau am eigenen Charakter. Das Oberteil bleibt in der Gangfarbe,
--  der Rest ist frei. Gespeichert wird auf dem Server.
-- =======================================================================

Wardrobe = { open = false, work = nil, cam = nil }

local function nui(data) SendNUIMessage(data) end

local function slotCfg(key)
    for _, s in ipairs(Config.Wardrobe.slots or {}) do
        if s.key == key then return s end
    end
end

local function copy(t)
    local out = {}
    for k, v in pairs(t or {}) do out[k] = type(v) == 'table' and { d = v.d, t = v.t, v = v.v } or v end
    return out
end

-- Aktuelle Werte vom Charakter lesen, wenn noch nichts gespeichert ist
local function readCurrent(ped, work)
    for _, s in ipairs(Config.Wardrobe.slots or {}) do
        if not work[s.key] then
            if s.gang then
                local item = Config.Outfits.items[s.key]
                local cur = item and GetPedDrawableVariation(ped, item.component)
                local v = 1
                for i, var in ipairs(item and item.variants or {}) do if var.drawable == cur then v = i end end
                work[s.key] = { v = v }
            elseif s.prop then
                work[s.key] = { d = GetPedPropIndex(ped, s.prop), t = math.max(0, GetPedPropTextureIndex(ped, s.prop)) }
            else
                work[s.key] = { d = GetPedDrawableVariation(ped, s.component), t = GetPedTextureVariation(ped, s.component) }
            end
        end
    end
end

local function counts(ped, s, d)
    if s.prop then
        local maxD = GetNumberOfPedPropDrawableVariations(ped, s.prop)
        local maxT = d >= 0 and GetNumberOfPedPropTextureVariations(ped, s.prop, d) or 0
        return maxD, maxT
    end
    local maxD = GetNumberOfPedDrawableVariations(ped, s.component)
    return maxD, GetNumberOfPedTextureVariations(ped, s.component, d)
end

local function stateFor()
    local ped = PlayerPedId()
    local out = {}
    for _, s in ipairs(Config.Wardrobe.slots or {}) do
        local v = Wardrobe.work[s.key] or {}
        local row = { key = s.key, label = s.label, gang = s.gang == true }
        if s.gang then
            local item = Config.Outfits.items[s.key]
            local list = item and Outfit.variants(ped, item) or {}
            local pos = 1
            for i, idx in ipairs(list) do if idx == v.v then pos = i end end
            row.value = ('Variante %d / %d'):format(pos, math.max(1, #list))
        else
            local maxD, maxT = counts(ped, s, v.d or 0)
            row.value = (s.prop and (v.d or -1) < 0) and 'Keine' or ('Modell %d / %d'):format((v.d or 0) + 1, maxD)
            row.texture = (s.prop and (v.d or -1) < 0) and '–' or ('Farbe %d / %d'):format((v.t or 0) + 1, math.max(1, maxT))
        end
        out[#out + 1] = row
    end
    return out
end

local function preview()
    Outfit.apply(PvP.team and PvP.team.outfit or 'silver', PvP.uid, Wardrobe.work)
end

local function startCam()
    local ped = PlayerPedId()
    local pos = GetOffsetFromEntityInWorldCoords(ped, -0.4, 2.3, 0.35)
    Wardrobe.cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, 45.0, false, 0)
    PointCamAtEntity(Wardrobe.cam, ped, 0.0, 0.0, 0.05, true)
    SetCamActive(Wardrobe.cam, true)
    RenderScriptCams(true, true, 500, true, true)
end

local function stopCam()
    if not Wardrobe.cam then return end
    RenderScriptCams(false, true, 400, true, true)
    DestroyCam(Wardrobe.cam, false)
    Wardrobe.cam = nil
end

function Wardrobe.show()
    if Wardrobe.open then return end
    if not (Config.Wardrobe and Config.Wardrobe.enabled ~= false) then return end
    if not PvP.loggedIn or PvP.dead or PvP.mode ~= 'lobby' then return HUD.notify('error', 'Umziehen geht nur an deiner Hood.') end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return HUD.notify('error', 'Steig zuerst aus.') end
    if UI.screen then UI.close(UI.screen) end
    Wardrobe.open = true
    Wardrobe.work = copy(PvP.account and PvP.account.outfit)
    readCurrent(ped, Wardrobe.work)
    FreezeEntityPosition(ped, true)
    SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
    startCam()
    UI.openScreen('wardrobe', { type = 'wardrobe', slots = stateFor() })
end

function Wardrobe.close(save)
    if not Wardrobe.open then return end
    Wardrobe.open = false
    if save then
        TriggerServerEvent('bspvp:outfit:save', Wardrobe.work)
        if PvP.account then PvP.account.outfit = copy(Wardrobe.work) end
    else
        Outfit.apply(PvP.team and PvP.team.outfit or 'silver', PvP.uid, PvP.account and PvP.account.outfit)
    end
    FreezeEntityPosition(PlayerPedId(), false)
    stopCam()
    UI.close('wardrobe')
end

RegisterCommand('kleidung', function() Wardrobe.show() end, false)
RegisterCommand('kleiderschrank', function() Wardrobe.show() end, false)

RegisterNUICallback('wardrobeChange', function(data, cb)
    if not Wardrobe.open or type(data) ~= 'table' then return cb({}) end
    local s = slotCfg(tostring(data.slot))
    local dir = tonumber(data.dir) == -1 and -1 or 1
    if not s then return cb({}) end
    local ped = PlayerPedId()
    local v = Wardrobe.work[s.key] or {}
    if s.gang then
        local list = Outfit.variants(ped, Config.Outfits.items[s.key])
        local pos = 1
        for i, idx in ipairs(list) do if idx == v.v then pos = i end end
        pos = ((pos - 1 + dir) % math.max(1, #list)) + 1
        v.v = list[pos] or 1
    elseif data.field == 't' then
        local _, maxT = counts(ped, s, v.d or 0)
        if maxT > 0 then v.t = ((v.t or 0) + dir) % maxT end
    else
        local maxD = counts(ped, s, 0)
        local low = s.prop and -1 or 0
        local span = maxD - low
        v.d = (((v.d or low) - low + dir) % math.max(1, span)) + low
        v.t = 0
    end
    Wardrobe.work[s.key] = v
    preview()
    cb({ slots = stateFor() })
end)

RegisterNUICallback('wardrobeRotate', function(data, cb)
    local ped = PlayerPedId()
    SetEntityHeading(ped, (GetEntityHeading(ped) + (tonumber(data and data.dir) or 1) * 45.0) % 360.0)
    cb({})
end)

RegisterNUICallback('wardrobeSave', function(_, cb) Wardrobe.close(true) cb({}) end)
RegisterNUICallback('wardrobeCancel', function(_, cb) Wardrobe.close(false) cb({}) end)

-- Moduswechsel oder Tod: ohne Speichern schließen
RegisterNetEvent('bspvp:mode', function() if Wardrobe.open then Wardrobe.close(false) end end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and Wardrobe.open then
        FreezeEntityPosition(PlayerPedId(), false)
        stopCam()
    end
end)
