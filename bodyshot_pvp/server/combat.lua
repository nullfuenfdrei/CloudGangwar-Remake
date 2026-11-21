-- =======================================================================
--  Kampf: Bodyshot-System
--  Der Server zählt jeden Treffer selbst (Weste zuerst, dann Leben).
--  FFA: jeder gegen jeden. Gangwar: nur gegen das andere Team, nur im Kampf
--  und nur in der Bubble. Hood: gegen andere Teams (Config.HoodCombat).
-- =======================================================================

Combat = {}

local ANNOUNCE = {}
for _, n in ipairs(Config.KillstreakAnnounce or {}) do ANNOUNCE[n] = true end

local function teamColor(p)
    local info = Teams.info(p.team)
    return info and info.color or nil
end

function Combat.canDamage(a, v)
    if not a.loggedIn or not v.loggedIn or a.dead or v.dead then return false end
    if a.mode ~= v.mode then return false end
    if a.mode == 'lobby' then
        return Config.HoodCombat == true and not Teams.same(a.team, v.team)
    end
    if a.mode == 'ffa' then return a.arena ~= nil and a.arena == v.arena end
    if a.mode == 'gangwar' then
        if not a.warId or a.warId ~= v.warId then return false end
        local war = Gangwar.wars[a.warId]
        if not war or war.phase ~= 'fight' then return false end
        if a.side == v.side then return false end
        -- nur in der Bubble (kein Beschuss vom Spawn aus)
        return Gangwar.inBubble(war, a.src) and Gangwar.inBubble(war, v.src)
    end
    if a.mode == 'duel' then
        local duel = a.duelId and Duels.list[a.duelId]
        return duel ~= nil and a.duelId == v.duelId and duel.phase == 'fight'
    end
    return false
end

-- -----------------------------------------------------------------------
--  Tod & Kill
-- -----------------------------------------------------------------------
-- Alles über den Killer für den Todesbildschirm (Profilbild, Level, K/D …)
function Combat.killerCard(killer, hp, armour)
    local s = killer.acc.stats
    local info = Teams.info(killer.team)
    local dp = killer.acc.discordProfile or {}
    local booster = killer.acc.discord ~= nil and DiscordRoles ~= nil and DiscordRoles.isBooster(killer.acc.discord)
    return {
        -- Server-Booster: Discord-Banner (oder Profilfarbe) auf der Karte
        booster = booster,
        banner = booster and dp.banner or nil,
        accent = booster and dp.accent or nil,
        discordName = dp.name,
        rank = Staff.info(Staff.rank(killer.src)),
        id = killer.acc.id,
        src = killer.src,               -- für das Charakter-Foto auf dem Client
        name = killer.acc.name,
        hp = hp or killer.hp,
        armour = armour or killer.armour,
        level = Accounts.level(killer.acc),
        kills = s.kills,
        deaths = s.deaths,
        best = s.best,
        streak = killer.streak,
        gwWins = s.gwWins,
        premium = killer.acc.premium,
        avatar = killer.avatar,         -- Discord-Profilbild (falls vorhanden)
        team = info and { name = info.name, tag = info.tag, color = info.color } or nil,
    }
end
function Combat.handleDeath(victim, killer, weapon, cause)
    if victim.dead then return end
    local t = Now()

    -- Kurz vorher getroffen? Dann bekommt der Schütze den Kill (kein Kill-Klau per /kill)
    if not killer and victim.lastHit and (t - victim.lastHit.at) <= (Config.KillCreditSeconds or 10) * 1000 then
        local credited = Players[victim.lastHit.by]
        if credited and Modes.sameWorldAs(credited, victim) then
            killer, weapon, cause = credited, victim.lastHit.weapon, 'shot'
        end
    end
    if killer == victim then killer = nil end

    -- 1v1-Duell: zählt nur für das Duell (keine Kills/Tode/Serien/Kopfgeld)
    if victim.mode == 'duel' then
        victim.dead = true
        victim.hp, victim.armour = 0, 0
        victim.spawnAllowedAt = t + 3600000           -- die nächste Runde stellt beide neu hin
        victim.protectedUntil = 0
        victim.lastHit = nil
        TriggerClientEvent('bspvp:died', victim.src, {
            killer = killer and Combat.killerCard(killer) or nil,
            weapon = weapon and weapon.label or nil, cause = cause, duel = true,
        })
        if killer then TriggerClientEvent('bspvp:killConfirm', killer.src, victim.acc.name, 0, 0) end
        Duels.onDeath(victim, killer)
        return
    end

    local rules = Modes.rules(victim)
    victim.dead = true
    victim.hp, victim.armour = 0, 0
    victim.spawnAllowedAt = t + (rules.respawn or 3) * 1000
    victim.protectedUntil = 0
    victim.lastHit = nil

    local endedStreak = victim.streak
    victim.streak = 0
    victim.acc.stats.deaths = victim.acc.stats.deaths + 1

    local killerInfo
    if killer then
        -- Restleben VOR der Belohnung (für den Todesbildschirm)
        local hp, armour = killer.hp, killer.armour

        local ks = killer.acc.stats
        ks.kills = ks.kills + 1
        killer.streak = killer.streak + 1
        if killer.streak > ks.best then ks.best = killer.streak end
        killerInfo = Combat.killerCard(killer, hp, armour)

        -- Tagesmissionen
        Missions.track(killer.acc, 'kill', 1, killer)
        if victim.mode == 'gangwar' then
            Missions.track(killer.acc, 'gwKill', 1, killer)
        elseif victim.mode == 'ffa' then
            Missions.track(killer.acc, 'ffaKill', 1, killer)
        end
        Missions.track(killer.acc, 'streak', killer.streak, killer)

        local reward = rules.reward
        if reward then
            Accounts.addMoney(killer.acc, reward.money or 0)
            Accounts.addXp(killer, reward.xp or 0)
        end

        local heal = rules.killReward
        if not killer.dead and heal and ((heal.health or 0) > 0 or (heal.armour or 0) > 0) then
            killer.hp = math.min(Config.MaxHealth, killer.hp + (heal.health or 0))
            killer.armour = math.min(Config.MaxArmour, killer.armour + (heal.armour or 0))
            SendVitals(killer)
        end
        if not killer.dead and Config.Ammo.refillOnKill then
            TriggerClientEvent('bspvp:refill', killer.src)
        end

        TriggerClientEvent('bspvp:killConfirm', killer.src, victim.acc.name, killer.streak, reward and reward.money or 0)
        if victim.mode == 'gangwar' then Gangwar.onKill(killer, victim) end
        Bounty.onKill(killer, victim)
        Bounty.onStreak(killer, killer.streak)

        if ANNOUNCE[killer.streak] then
            for _, q in ipairs(Modes.sameWorld(killer)) do
                Announce(q.src, ('%s hat %d Kills in Folge!'):format(killer.acc.name, killer.streak))
            end
        end
        if endedStreak >= 5 then
            for _, q in ipairs(Modes.sameWorld(killer)) do
                Announce(q.src, ('%s beendet die %der-Serie von %s'):format(killer.acc.name, endedStreak, victim.acc.name))
            end
        end
        Accounts.save(killer.acc)
        Accounts.push(killer)
    end

    Accounts.save(victim.acc)
    Accounts.push(victim)

    Logs.add('kill', killer
        and ('%s tötet %s mit %s (%s)'):format(Logs.who(killer), Logs.who(victim), weapon and weapon.label or '?', Progress.placeName(victim))
        or ('%s stirbt (%s, %s)'):format(Logs.who(victim), tostring(cause), Progress.placeName(victim)))

    TriggerClientEvent('bspvp:died', victim.src, {
        killer = killerInfo,
        weapon = weapon and weapon.label or nil,
        cause = cause,
        respawn = rules.respawn,
    })

    Modes.broadcast(victim, 'bspvp:killfeed', {
        killer = killer and killer.acc.name or nil,
        killerId = killer and killer.src or nil,
        killerColor = killer and teamColor(killer) or nil,
        victim = victim.acc.name,
        victimId = victim.src,
        victimColor = teamColor(victim),
        weapon = weapon and weapon.label or nil,
        cause = cause,
        streak = killer and killer.streak or 0,
    })
end

-- -----------------------------------------------------------------------
--  Treffer
-- -----------------------------------------------------------------------
local function applyHit(attacker, victim, weapon, damage, zone, fromCoords)
    local absorb = 0
    if victim.armour > 0 then
        absorb = math.min(victim.armour, math.floor(damage * (Config.ArmourAbsorb or 1.0) + 0.5))
        victim.armour = victim.armour - absorb
    end
    victim.hp = victim.hp - (damage - absorb)
    victim.lastHit = { by = attacker.src, weapon = weapon, at = Now() }

    local fatal = victim.hp <= 0
    if fatal then victim.hp = 0 end

    TriggerClientEvent('bspvp:hit', victim.src, {
        hp = victim.hp,
        armour = victim.armour,
        dmg = damage,
        armourHit = absorb > 0,
        from = fromCoords and { x = fromCoords.x, y = fromCoords.y, z = fromCoords.z } or nil,
    })
    TriggerClientEvent('bspvp:hitConfirm', attacker.src, damage, zone, absorb > 0, fatal)
    Missions.track(attacker.acc, 'hit', 1, attacker)

    if fatal then Combat.handleDeath(victim, attacker, weapon, 'shot') end
end

local function resolveVictim(data)
    local netId = tonumber(data.hitGlobalId)
    if (not netId or netId == 0) and type(data.hitGlobalIds) == 'table' then
        netId = tonumber(data.hitGlobalIds[1])
    end
    if not netId or netId == 0 then return nil end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end
    if GetEntityType(entity) ~= 1 then return nil end   -- 1 = Ped

    local owner = NetworkGetEntityOwner(entity)
    if owner and owner > 0 and GetPlayerPed(owner) == entity then return owner end
    for _, id in ipairs(GetPlayers()) do
        local s = tonumber(id)
        if GetPlayerPed(s) == entity then return s end
    end
    return nil
end

AddEventHandler('weaponDamageEvent', function(sender, data)
    sender = tonumber(sender)
    if not sender or type(data) ~= 'table' then return end

    local victimSrc = resolveVictim(data)
    if not victimSrc or victimSrc == sender then return end   -- kein Spieler getroffen

    local weapon = Weapons.fromHash(data.weaponType)
    if not weapon then
        if Config.BlockOtherWeapons then CancelEvent() end      -- Pistole, Faust ... = 0 Schaden
        return
    end

    local attacker, victim = Players[sender], Players[victimSrc]
    if not attacker or not victim then return end
    if not Combat.canDamage(attacker, victim) then
        CancelEvent()                                            -- Teamkamerad, Lobby, Vorbereitung
        return
    end
    local allowed
    if attacker.mode == 'duel' then
        allowed = Duels.weaponOf(attacker) == weapon.name           -- im Duell nur die Duell-Waffe
    else
        allowed = Accounts.owns(attacker.acc, weapon.name)
    end
    if not allowed then
        CancelEvent()                                            -- nicht gekaufte Waffe (Cheat)
        -- im Duell kann das kurz nach dem Ende durch Lag passieren -> nur melden
        AntiCheat.flag(sender, 'damageWeapon', ('Schaden mit %s, nicht im Besitz'):format(weapon.label),
            attacker.mode == 'duel' and 'log' or nil)
        return
    end

    local t = Now()
    if attacker.protectedUntil > t then
        attacker.protectedUntil = 0
        TriggerClientEvent('bspvp:protection', sender, false)
    end
    if victim.protectedUntil > t then return end

    if t - attacker.rateStart >= 1000 then
        attacker.rateStart, attacker.rateCount = t, 0
    end
    attacker.rateCount = attacker.rateCount + 1
    if attacker.rateCount > (Config.MaxHitsPerSecond or 20) then return end

    local aPos = GetEntityCoords(GetPlayerPed(sender))
    local vPos = GetEntityCoords(GetPlayerPed(victimSrc))
    if #(aPos - vPos) > weapon.range then return end

    local zone = Weapons.zoneOf(data.hitComponent)
    local mult = (Config.ZoneMultiplier and Config.ZoneMultiplier[zone]) or 1.0
    local damage = math.max(1, math.floor(weapon.damage * mult + 0.5))

    applyHit(attacker, victim, weapon, damage, zone, aPos)
end)

-- -----------------------------------------------------------------------
--  Client -> Server
-- -----------------------------------------------------------------------
RegisterNetEvent('bspvp:spawned', function()
    local p = Players[source]
    if not p or not p.loggedIn or not p.dead then return end      -- schon am Leben -> ignorieren
    if p.mode ~= 'lobby' and p.mode ~= 'ffa' and p.mode ~= 'gangwar' and p.mode ~= 'duel' then return end
    local t = Now()
    if t < p.spawnAllowedAt - 750 then return end                -- zu früh

    p.dead = false
    p.hp = Config.MaxHealth
    p.armour = math.min(Config.MaxArmour, Config.SpawnArmour or Config.MaxArmour)
    p.lastHit = nil
    p.using = nil
    -- Der Server bekommt die neue Position erst kurz nach dem Spawn -> keine Teleport-Meldung
    AntiCheat.allowMove(p.src, 6)
    local fights = p.mode == 'ffa' or p.mode == 'gangwar' or (p.mode == 'lobby' and Config.HoodCombat)
    local protection = fights and (Config.SpawnProtectionSeconds or 0) or 0
    p.protectedUntil = t + protection * 1000
    SendVitals(p)
    if protection > 0 then
        TriggerClientEvent('bspvp:protection', p.src, true, protection)
    end
end)

RegisterNetEvent('bspvp:endProtection', function()
    local p = Players[source]
    if p then p.protectedUntil = 0 end
end)

-- Kämpft man in diesem Modus? (Hood nur mit Config.HoodCombat)
local function fightMode(p)
    return p.mode == 'ffa' or p.mode == 'gangwar' or p.mode == 'duel' or (p.mode == 'lobby' and Config.HoodCombat == true)
end

-- Fallschaden & Co. (nur gegen sich selbst, nicht in einer Safezone-Hood)
RegisterNetEvent('bspvp:envDamage', function(amount)
    local p = Players[source]
    if not p or not p.loggedIn or p.dead then return end
    if not fightMode(p) then return end
    amount = tonumber(amount)
    if not amount then return end
    amount = math.floor(math.min(math.max(amount, 0), 500))
    if amount <= 0 or p.protectedUntil > Now() then return end

    p.hp = p.hp - amount
    if p.hp <= 0 then
        p.hp = 0
        Combat.handleDeath(p, nil, nil, 'fall')
    else
        SendVitals(p)
    end
end)

RegisterNetEvent('bspvp:envDeath', function()
    local p = Players[source]
    if not p or not p.loggedIn or p.dead then return end
    if fightMode(p) then
        Combat.handleDeath(p, nil, nil, 'world')
    elseif p.mode == 'lobby' then
        p.dead = true
        p.spawnAllowedAt = Now()
        TriggerClientEvent('bspvp:died', p.src, { cause = 'world', respawn = 1 })
    end
end)
