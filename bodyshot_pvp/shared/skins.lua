-- =======================================================================
--  Waffen-Skins (Client + Server)
--  Aus Config.Skins wird für jede Waffe der Config die Liste der möglichen
--  Skins gebaut. Skin-ID: <WAFFE>:t<Farbton> | <WAFFE>:c<Muster> | <WAFFE>:f
-- =======================================================================

Skins = {
    list = {},        -- alle Skins
    byId = {},
    byWeapon = {},    -- ['WEAPON_...'] = { skins }
    rarity = {},      -- ['common'] = { key, name, color, duplicate, order }
}

for i, r in ipairs(Config.Rarities or {}) do
    Skins.rarity[r.key] = { key = r.key, name = r.name, color = r.color, duplicate = r.duplicate or 0, order = i }
end

-- Form des Gewehrs für das Bild im Menü
local function shapeOf(name)
    if name:find('BULLPUP') then return 'bullpup' end
    if name:find('GUSENBERG') then return 'tommy' end
    if name:find('COMPACT') then return 'compact' end
    if name:find('CARBINE') or name:find('MILITARY') or name:find('TACTICAL') then return 'carbine' end
    if name:find('ADVANCED') then return 'bullpup' end
    return 'rifle'
end
Skins.shapeOf = shapeOf

local function add(skin)
    if not Skins.rarity[skin.rarity] then return end
    Skins.list[#Skins.list + 1] = skin
    Skins.byId[skin.id] = skin
    Skins.byWeapon[skin.weapon] = Skins.byWeapon[skin.weapon] or {}
    table.insert(Skins.byWeapon[skin.weapon], skin)
end

local cfg = Config.Skins or {}
for _, w in ipairs(Weapons.list) do
    local mk2 = w.name:find('_MK2', 1, true) ~= nil
    local shape = shapeOf(w.name)
    if mk2 then
        local base = w.name:gsub('^WEAPON_', ''):gsub('_MK2$', '')
        for _, t in ipairs(cfg.mk2Tints or {}) do
            add({ id = w.name .. ':t' .. t.tint, weapon = w.name, weaponLabel = w.label, kind = 'mk2tint', tint = t.tint,
                  name = t.name, rarity = t.rarity, colors = t.colors, shape = shape })
        end
        for i, c in ipairs(cfg.camos or {}) do
            add({ id = w.name .. ':c' .. i, weapon = w.name, weaponLabel = w.label, kind = 'camo',
                  component = ('COMPONENT_%s_MK2_CAMO%s'):format(base, c.suffix or ''),
                  name = c.name, rarity = c.rarity, pattern = c.pattern, shape = shape })
        end
    else
        for _, t in ipairs(cfg.tints or {}) do
            add({ id = w.name .. ':t' .. t.tint, weapon = w.name, weaponLabel = w.label, kind = 'tint', tint = t.tint,
                  name = t.name, rarity = t.rarity, colors = t.colors, shape = shape })
        end
        local f = (cfg.finishes or {})[w.name]
        if f then
            add({ id = w.name .. ':f', weapon = w.name, weaponLabel = w.label, kind = 'finish', component = f.component,
                  name = f.name, rarity = 'legendary', pattern = 'luxe', shape = shape })
        end
    end
end

function Skins.get(id) return id and Skins.byId[tostring(id)] or nil end

function Skins.case(key)
    for _, c in ipairs(Config.Cases or {}) do
        if c.key == key then return c end
    end
    return nil
end

-- Alle Skins, die in einer Case stecken können
function Skins.pool(caseKey)
    local c = Skins.case(caseKey)
    if not c then return {} end
    local kinds = {}
    for _, k in ipairs(c.kinds or {}) do kinds[k] = true end
    local out = {}
    for _, s in ipairs(Skins.list) do
        if kinds[s.kind] and (c.weights or {})[s.rarity] and c.weights[s.rarity] > 0 then out[#out + 1] = s end
    end
    return out
end

-- Für die NUI (ohne Komponenten-Namen)
function Skins.view(s)
    if not s then return nil end
    local r = Skins.rarity[s.rarity] or {}
    return {
        id = s.id, weapon = s.weapon, weaponLabel = s.weaponLabel, name = s.name, kind = s.kind,
        rarity = s.rarity, rarityName = r.name, rarityColor = r.color,
        colors = s.colors, pattern = s.pattern, shape = s.shape,
    }
end
