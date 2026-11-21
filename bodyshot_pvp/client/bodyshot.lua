-- =======================================================================
--  Client: Bodyshot-System
--
--  Leben und Weste zählt der Server. Der Client spiegelt die Werte auf
--  die normalen GTA-Balken unter der Minimap (100 HP = voller Balken).
--  GTA-Schaden durch Kugeln wird stark gedämpft und sofort wieder auf den
--  Server-Wert zurückgesetzt – so gibt es keine Headshot-One-Taps und die
--  Schusszahl bleibt exakt, die Minimap zeigt aber trotzdem alles normal an.
-- =======================================================================

Bodyshot = {
    guard = false,        -- aktiv, solange man lebt
    hp = 0,
    armour = 0,
    envPending = 0,
    envSince = 0,
    lastServerHit = -100000,
}

local MAX_HEALTH = 200    -- GTA-Standard: 100 = leer, 200 = voll
local HIT_WINDOW = 300    -- ms: GTA-Schaden so nah an einem Server-Treffer = Spieler-Treffer

local function nui(data) SendNUIMessage(data) end

-- Server-Werte -> GTA-Werte für die Minimap-Balken
local function wantedHealth()
    local hp = math.max(0, Bodyshot.hp)
    local percent = math.floor(hp / (Config.MaxHealth or 100) * 100 + 0.5)
    if hp > 0 then percent = math.max(1, percent) end
    return 100 + math.min(100, percent)
end

local function wantedArmour()
    local a = math.max(0, Bodyshot.armour)
    return math.min(100, math.floor(a / (Config.MaxArmour or 100) * 100 + 0.5))
end

function Bodyshot.setGuard(on)
    Bodyshot.guard = on
    if on then Bodyshot.envPending = 0 end
end

-- Aktuelle Server-Werte sofort auf den Ped schreiben
function Bodyshot.mirror(ped)
    ped = ped or PlayerPedId()
    if IsEntityDead(ped) or Bodyshot.hp <= 0 then return end   -- Tod kommt gleich vom Server
    if GetEntityMaxHealth(ped) ~= MAX_HEALTH then
        SetPedMaxHealth(ped, MAX_HEALTH)
        SetEntityMaxHealth(ped, MAX_HEALTH)
    end
    SetEntityHealth(ped, wantedHealth())
    SetPedArmour(ped, wantedArmour())
end

-- Beim Spawn: voll (der Server schickt gleich danach die echten Werte)
function Bodyshot.applyGameHealth(ped)
    ped = ped or PlayerPedId()
    Bodyshot.hp = Config.MaxHealth
    Bodyshot.armour = math.min(Config.MaxArmour, Config.SpawnArmour or Config.MaxArmour)
    SetPedMaxHealth(ped, MAX_HEALTH)
    SetEntityMaxHealth(ped, MAX_HEALTH)
    SetEntityHealth(ped, wantedHealth())
    SetPedArmour(ped, wantedArmour())
    SetPedSuffersCriticalHits(ped, false)   -- keine Headshot-Instakills
    ClearEntityLastDamageEntity(ped)
end

-- Umgebungsschaden nur melden, wenn kein Spieler-Treffer in der Nähe war
-- (egal ob der Server-Treffer vor oder nach dem GTA-Schaden ankommt)
local function flushEnvironmentDamage()
    if Bodyshot.envPending <= 0 then return end
    if GetGameTimer() < (Bodyshot.ignoreEnvUntil or 0) then     -- Admin-Troll: kein Fallschaden
        Bodyshot.envPending = 0
        return
    end
    if GetGameTimer() - Bodyshot.envSince < 250 then return end
    local percent = Bodyshot.envPending
    local amount = math.floor(percent / 100 * (Config.MaxHealth or 100) * (Config.EnvironmentDamage or 1.0) + 0.5)
    local nearHit = Bodyshot.lastServerHit >= Bodyshot.envSince - HIT_WINDOW
    Bodyshot.envPending = 0
    if amount > 0 and not nearHit then
        TriggerServerEvent('bspvp:envDamage', amount)
    end
end

-- Jede Frame: GTA-Werte auf Server-Werte halten, Umgebungsschaden erkennen
CreateThread(function()
    while true do
        if Bodyshot.guard then
            local ped = PlayerPedId()
            if not IsEntityDead(ped) and Bodyshot.hp > 0 then
                if GetEntityMaxHealth(ped) ~= MAX_HEALTH then
                    Bodyshot.mirror(ped)
                else
                    local want = wantedHealth()
                    local health = GetEntityHealth(ped)
                    if health < want then
                        -- Treffer von Spielern zählt der Server – nur der Rest ist Umgebung
                        local byPlayer = HasEntityBeenDamagedByAnyPed(ped)
                            or (GetGameTimer() - Bodyshot.lastServerHit) < HIT_WINDOW
                        if health > 0 and not byPlayer then
                            if Bodyshot.envPending == 0 then Bodyshot.envSince = GetGameTimer() end
                            Bodyshot.envPending = Bodyshot.envPending + (want - health)
                        end
                        SetEntityHealth(ped, want)
                        ClearEntityLastDamageEntity(ped)
                    elseif health > want then
                        SetEntityHealth(ped, want)       -- keine Heilung an der Server-Zählung vorbei
                    end
                    local armour = wantedArmour()
                    if GetPedArmour(ped) ~= armour then SetPedArmour(ped, armour) end
                end
            end
            flushEnvironmentDamage()
        end
        Wait(0)
    end
end)

-- Jede Sekunde: Headshot-Crits aus, GTA-Kugelschaden stark dämpfen
CreateThread(function()
    while true do
        SetPedSuffersCriticalHits(PlayerPedId(), false)
        SetPlayerWeaponDefenseModifier(PlayerId(), 0.1)
        Wait(1000)
    end
end)

-- -----------------------------------------------------------------------
--  Server -> Client
-- -----------------------------------------------------------------------
local function pushVitals()
    if Bodyshot.guard then Bodyshot.mirror() end
    nui({ type = 'vitals', hp = Bodyshot.hp, armour = Bodyshot.armour, maxHp = Config.MaxHealth, maxArmour = Config.MaxArmour })
end

-- Richtung des Schützen relativ zur Kamera (Grad, + = links)
local function relativeAngle(from)
    local pos = GetEntityCoords(PlayerPedId())
    local heading = GetHeadingFromVector_2d(from.x - pos.x, from.y - pos.y)
    local cam = GetGameplayCamRot(2).z
    return (heading - cam + 540.0) % 360.0 - 180.0
end

RegisterNetEvent('bspvp:vitals', function(hp, armour)
    Bodyshot.hp, Bodyshot.armour = hp or 0, armour or 0
    pushVitals()
end)

RegisterNetEvent('bspvp:hit', function(data)
    if type(data) ~= 'table' then return end
    Bodyshot.lastServerHit = GetGameTimer()
    Bodyshot.hp, Bodyshot.armour = data.hp or 0, data.armour or 0
    pushVitals()
    local angle
    if Config.Hud.damageDirection and data.from then angle = relativeAngle(data.from) end
    nui({ type = 'damaged', dmg = data.dmg, angle = angle, armour = data.armourHit })
end)

RegisterNetEvent('bspvp:hitConfirm', function(dmg, zone, armourHit, fatal)
    nui({ type = 'hit', dmg = dmg, zone = zone, armour = armourHit, kill = fatal })
end)

RegisterNetEvent('bspvp:killConfirm', function(victimName, streak, money)
    nui({ type = 'kill', victim = victimName, streak = streak, money = money })
end)
