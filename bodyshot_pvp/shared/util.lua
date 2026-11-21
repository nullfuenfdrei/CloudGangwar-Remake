-- Kleine Helfer für Client und Server

Util = {}

function Util.int(v)
    return math.floor(tonumber(v) or 0)
end

function Util.maxLevel()
    local max = 1
    for level in pairs(Config.Battlepass.rewards or {}) do
        if level > max then max = level end
    end
    return max
end

function Util.levelFromXp(xp)
    local per = Config.Battlepass.xpPerLevel or 1000
    return math.min(Util.maxLevel(), math.floor((tonumber(xp) or 0) / per) + 1)
end

-- Fortschritt im aktuellen Level (0..1)
function Util.levelProgress(xp)
    local per = Config.Battlepass.xpPerLevel or 1000
    xp = tonumber(xp) or 0
    if Util.levelFromXp(xp) >= Util.maxLevel() then return 1.0 end
    return (xp % per) / per
end

function Util.formatMoney(n)
    local s = tostring(Util.int(n))
    local neg = s:sub(1, 1) == '-'
    if neg then s = s:sub(2) end
    local out = s:reverse():gsub('(%d%d%d)', '%1.'):reverse()
    out = out:gsub('^%.', '')
    return (neg and '-' or '') .. out
end

function Util.hexToRgb(hex)
    hex = tostring(hex or '#ffffff'):gsub('#', '')
    if #hex ~= 6 then return { 255, 255, 255 } end
    return { tonumber(hex:sub(1, 2), 16) or 255, tonumber(hex:sub(3, 4), 16) or 255, tonumber(hex:sub(5, 6), 16) or 255 }
end

function Util.gang(id)
    for _, g in ipairs(Config.Gangs) do
        if g.id == id then return g end
    end
    return nil
end

function Util.zone(key)
    for _, z in ipairs(Config.Zones) do
        if z.key == key then return z end
    end
    return nil
end

-- Gangwar: grober Spawnpunkt eines Teams (außerhalb der Bubble, Teams gegenüber).
-- Der Client setzt ihn danach auf die nächste Straße.
function Util.gwSpawnBase(z, side)
    local fixed = side == 'defender' and z.defenderSpawn or z.attackerSpawn
    if fixed then return vector3(fixed.x, fixed.y, fixed.z) end
    local angle = math.rad((z.spawnAngle or 0) + (side == 'defender' and 180 or 0))
    local dist = z.spawnDistance or Config.Gangwar.spawnDistance or 170.0
    return vector3(z.center.x + math.sin(angle) * dist, z.center.y + math.cos(angle) * dist, z.center.z)
end

-- Gangwar: so weit darf man sich von der Mitte entfernen (Spawn + Weg zur Bubble)
function Util.gwBoundary(z)
    local far = z.spawnDistance or Config.Gangwar.spawnDistance or 170.0
    for _, s in ipairs({ z.attackerSpawn, z.defenderSpawn }) do
        if s then
            local dx, dy = s.x - z.center.x, s.y - z.center.y
            far = math.max(far, math.sqrt(dx * dx + dy * dy))
        end
    end
    return far + (Config.Gangwar.boundaryExtra or 130.0)
end

-- Gangwar: Punkt in der Bubble? (Kugel, damit Dächer darüber nicht zählen)
function Util.inBubble(z, pos, extra)
    local dx, dy, dz = pos.x - z.center.x, pos.y - z.center.y, pos.z - z.center.z
    local r = z.radius + (extra or 0.0)
    return dx * dx + dy * dy + dz * dz <= r * r
end

function Util.gwVehicle(model)
    model = string.lower(tostring(model or ''))
    for _, v in ipairs(Config.Gangwar.vehicles or {}) do
        if string.lower(v.model) == model then return v end
    end
    return nil
end

function Util.arena(index)
    return Config.Arenas[Util.int(index)]
end

function Util.vehicle(model)
    model = string.lower(tostring(model or ''))
    for _, v in ipairs(Config.Garage.vehicles or {}) do
        if string.lower(v.model) == model then return v end
    end
    return nil
end

-- Outfit-Farbe einer Private-Team-Farbe
function Util.privateOutfit(hex)
    for _, c in ipairs(Config.PrivateTeams.colors or {}) do
        if c.hex == hex then return c.outfit end
    end
    return 'silver'
end

function Util.privateColorAllowed(hex)
    for _, c in ipairs(Config.PrivateTeams.colors or {}) do
        if c.hex == hex then return true end
    end
    return false
end

-- vector3/vector4 -> einfache Tabelle (für Events und JSON)
function Util.vec(v)
    if not v then return nil end
    return { x = v.x + 0.0, y = v.y + 0.0, z = v.z + 0.0, w = (v.w or 0.0) + 0.0 }
end

function Util.trim(s)
    return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end
