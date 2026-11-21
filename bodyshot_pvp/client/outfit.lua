-- =======================================================================
--  Client: Freemode-Charakter im Outfit seines Teams
--  Gesicht, Frisur und Bart hängen an der User-ID – jeder Spieler sieht
--  also jedes Mal gleich aus, nur die Kleidung trägt die Teamfarbe.
-- =======================================================================

Outfit = {}

local MODEL = 'mp_m_freemode_01'
local HAIR = { 0, 1, 2, 3, 4, 5, 8, 9, 10, 11, 12, 13, 14, 16, 17, 18, 19, 21, 22 }
local HAIR_COLORS = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 17, 18, 19, 26, 28 }
local BEARDS = { -1, -1, 0, 1, 2, 3, 4, 5, 7, 10, 11, 12, 13, 14, 18, 19, 20, 28 }   -- -1 = rasiert

-- Kleiner Zufallsgenerator, der für dieselbe User-ID immer dasselbe liefert
local function seeded(seed)
    local s = (math.floor(tonumber(seed) or 0) * 2654435761 + 12345) % 2147483648
    return function(n)
        s = (s * 1103515245 + 12345) % 2147483648
        return (s // 65536) % n + 1
    end
end

local function loadModel(name)
    local hash = GetHashKey(name)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(0) end
    return HasModelLoaded(hash) and hash or nil
end

-- Erste Variante, die es im Spiel gibt (neue Kleidung braucht Gamebuild 3095)
local function pickVariant(ped, item)
    for i, v in ipairs(item.variants or {}) do
        local count
        if item.prop then
            count = GetNumberOfPedPropDrawableVariations(ped, item.prop)
        else
            count = GetNumberOfPedDrawableVariations(ped, item.component)
        end
        if v.drawable < (count or 0) then return v, i end
    end
    return nil
end

local function textureFor(ped, item, drawable, wanted)
    local count
    if item.prop then
        count = GetNumberOfPedPropTextureVariations(ped, item.prop, drawable)
    else
        count = GetNumberOfPedTextureVariations(ped, item.component, drawable)
    end
    wanted = wanted or 0
    if not count or count <= 0 or wanted >= count then return 0 end
    return wanted
end

local function face(ped, roll)
    local father, mother = roll(21) - 1, 20 + roll(21)          -- 0..20 Väter, 21..41 Mütter
    local skinA, skinB = roll(21) - 1, 20 + roll(21)
    local shapeMix = 0.15 + (roll(30) - 1) / 100                 -- überwiegend vom Vater
    local skinMix = (roll(100) - 1) / 100
    SetPedHeadBlendData(ped, father, mother, 0, skinA, skinB, 0, shapeMix, skinMix, 0.0, false)

    local hair = HAIR[roll(#HAIR)]
    local color = HAIR_COLORS[roll(#HAIR_COLORS)]
    SetPedComponentVariation(ped, 2, hair, 0, 0)
    SetPedHairColor(ped, color, color)

    local beard = BEARDS[roll(#BEARDS)]
    if beard >= 0 then
        SetPedHeadOverlay(ped, 1, beard, 0.7 + (roll(30) - 1) / 100)
        SetPedHeadOverlayColor(ped, 1, 1, color, color)
    else
        SetPedHeadOverlay(ped, 1, 255, 0.0)
    end
    SetPedHeadOverlay(ped, 2, roll(12) - 1, 0.9)                -- Augenbrauen
    SetPedHeadOverlayColor(ped, 2, 1, color, color)
end

-- Varianten eines Gang-Teils, die es im Spiel gibt (für den Kleiderschrank)
function Outfit.variants(ped, item)
    local out = {}
    for i, v in ipairs(item.variants or {}) do
        local count = item.prop and GetNumberOfPedPropDrawableVariations(ped, item.prop) or GetNumberOfPedDrawableVariations(ped, item.component)
        if v.drawable < (count or 0) then out[#out + 1] = i end
    end
    return out
end

-- Eigene Teile aus dem Kleiderschrank (Hose, Schuhe, Hut, Brille, Kette)
local function applyCustom(ped, outfit)
    for _, s in ipairs(Config.Wardrobe and Config.Wardrobe.slots or {}) do
        local v = outfit[s.key]
        if not s.gang and type(v) == 'table' and v.d ~= nil then
            local d, t = math.floor(tonumber(v.d) or 0), math.floor(tonumber(v.t) or 0)
            if s.prop then
                if d < 0 then ClearPedProp(ped, s.prop)
                elseif d < GetNumberOfPedPropDrawableVariations(ped, s.prop) then
                    local tc = GetNumberOfPedPropTextureVariations(ped, s.prop, d)
                    SetPedPropIndex(ped, s.prop, d, (tc > 0 and t < tc) and t or 0, true)
                end
            elseif s.component and d >= 0 and d < GetNumberOfPedDrawableVariations(ped, s.component) then
                local tc = GetNumberOfPedTextureVariations(ped, s.component, d)
                SetPedComponentVariation(ped, s.component, d, (tc > 0 and t < tc) and t or 0, 0)
            end
        end
    end
end
Outfit.applyCustom = applyCustom

-- Sorgt für das Freemode-Model und zieht das Team-Outfit an.
-- outfit = gespeicherte Auswahl aus dem Kleiderschrank (optional)
function Outfit.apply(colorKey, uid, outfit)
    outfit = type(outfit) == 'table' and outfit or {}
    local cfg = Config.Outfits or {}
    local ped = PlayerPedId()
    local hash = GetHashKey(MODEL)
    if GetEntityModel(ped) ~= hash then
        if not loadModel(MODEL) then return false end
        SetPlayerModel(PlayerId(), hash)
        SetModelAsNoLongerNeeded(hash)
        ped = PlayerPedId()
        SetPedDefaultComponentVariation(ped)
    end

    local roll = seeded(uid)
    face(ped, roll)

    -- Alles Störende aus: Maske, Tasche, Accessoires, Weste, Aufkleber
    for _, c in ipairs({ 1, 5, 7, 9, 10 }) do SetPedComponentVariation(ped, c, 0, 0, 0) end
    SetPedComponentVariation(ped, 8, cfg.undershirt or 15, 0, 0)
    for _, p in ipairs({ 0, 1, 2, 6, 7 }) do ClearPedProp(ped, p) end

    local colors = (cfg.colors or {})[colorKey] or (cfg.colors or {}).silver or {}
    local names = {}
    for name in pairs(cfg.items or {}) do names[#names + 1] = name end
    table.sort(names)                       -- feste Reihenfolge = immer gleicher Look
    for _, name in ipairs(names) do
        local item = cfg.items[name]
        local v, index = pickVariant(ped, item)
        -- Oberteil: gewählte Gang-Variante (bleibt in der Gangfarbe)
        local chosen = outfit[name] and tonumber(outfit[name].v)
        if chosen and item.variants and item.variants[chosen] then
            local cv = item.variants[chosen]
            local count = item.prop and GetNumberOfPedPropDrawableVariations(ped, item.prop) or GetNumberOfPedDrawableVariations(ped, item.component)
            if cv.drawable < (count or 0) then v, index = cv, chosen end
        end
        local wantTex = colors[name] and colors[name][index] or 0
        if item.prop then
            local wear = v and roll(100) <= math.floor((item.chance or 1.0) * 100)
            if wear then
                SetPedPropIndex(ped, item.prop, v.drawable, textureFor(ped, item, v.drawable, wantTex), true)
            end
        elseif v then
            SetPedComponentVariation(ped, item.component, v.drawable, textureFor(ped, item, v.drawable, wantTex), 0)
            if v.torso then SetPedComponentVariation(ped, 3, v.torso, 0, 0) end
        end
    end
    applyCustom(ped, outfit)
    return true
end
