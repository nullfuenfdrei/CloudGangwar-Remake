-- Waffen-Tabelle für Client und Server.
-- Rechnet aus "shots" den Schaden pro Treffer und baut Lookups per Hash.

Weapons = {
    list   = {},   -- Reihenfolge wie in der Config
    byHash = {},   -- [unsigned hash] = Waffe
    byName = {},   -- ['WEAPON_...'] = Waffe
}

local UINT32 = 4294967296

-- GetHashKey liefert signierte Zahlen, weaponDamageEvent unsignierte.
function Weapons.toUnsigned(hash)
    hash = tonumber(hash)
    if not hash then return nil end
    hash = math.floor(hash)
    if hash < 0 then hash = hash + UINT32 end
    return hash
end

Weapons.pool = (Config.MaxHealth or 100) + (Config.MaxArmour or 100)

for _, w in ipairs(Config.Weapons or {}) do
    local name = string.upper(w.name)
    local damage = tonumber(w.damage)
    if not damage then
        local shots = math.max(1, math.floor(tonumber(w.shots) or 17))
        damage = math.ceil(Weapons.pool / shots)
    end
    damage = math.max(1, math.floor(damage))

    local entry = {
        name       = name,
        label      = w.label or name,
        damage     = damage,
        shots      = tonumber(w.shots),
        realShots  = math.ceil(Weapons.pool / damage),
        price      = math.max(0, math.floor(tonumber(w.price) or 0)),
        range      = tonumber(w.range) or Config.MaxHitDistance or 350.0,
        components = w.components,
        hash       = GetHashKey(name),
    }
    entry.uhash = Weapons.toUnsigned(entry.hash)

    Weapons.list[#Weapons.list + 1] = entry
    Weapons.byHash[entry.uhash] = entry
    Weapons.byName[name] = entry
end

function Weapons.fromHash(hash)
    local u = Weapons.toUnsigned(hash)
    return u and Weapons.byHash[u] or nil
end

function Weapons.get(name)
    return name and Weapons.byName[string.upper(tostring(name))] or nil
end

-- GTA-Ragdoll-Komponenten (hitComponent im weaponDamageEvent):
-- 0 Becken, 1-6 Beine, 7-10 Wirbelsäule, 11/15 Schlüsselbeine,
-- 12-14 linker Arm, 16-18 rechter Arm, 19 Hals, 20 Kopf
local ZONES = {}
for _, c in ipairs({ 19, 20 }) do ZONES[c] = 'head' end
for _, c in ipairs({ 0, 7, 8, 9, 10, 11, 15 }) do ZONES[c] = 'torso' end
for _, c in ipairs({ 12, 13, 14, 16, 17, 18 }) do ZONES[c] = 'arms' end
for _, c in ipairs({ 1, 2, 3, 4, 5, 6 }) do ZONES[c] = 'legs' end

function Weapons.zoneOf(component)
    return ZONES[tonumber(component) or -1] or 'torso'
end
