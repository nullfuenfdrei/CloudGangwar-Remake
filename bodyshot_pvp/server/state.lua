-- =======================================================================
--  Gemeinsamer Server-Zustand + Helfer
-- =======================================================================

Players = {}       -- [source] = Spielerzustand (nur wer online ist)

function Now() return GetGameTimer() end

function GetLicense(src)
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        if string.sub(id, 1, 8) == 'license:' then return id end
    end
    return nil
end

function NewPlayerState(src)
    return {
        src = src,
        license = GetLicense(src),
        acc = nil,              -- Account (nach Login)
        loggedIn = false,
        team = nil,             -- { kind = 'gang'|'private', id = ... }
        mode = 'login',         -- login | select | lobby | ffa | gangwar | duel
        arena = nil,            -- FFA-Arena (Index)
        warId = nil,
        side = nil,             -- attacker | defender
        -- Kampf
        streak = 0,
        hp = 0,
        armour = 0,
        dead = true,
        spawnAllowedAt = 0,
        protectedUntil = 0,
        lastHit = nil,
        rateStart = 0,
        rateCount = 0,
        lastSuicide = 0,
        lastAction = 0,
        actionCount = 0,
        invite = nil,           -- { teamId, from, expires }
        -- Sonstiges
        chatTimes = {},
        playNext = 0,           -- nächster Spielzeit-Bonus (GetGameTimer)
        minuteAcc = 0,          -- Sekunden für die Missionen "Spiel X Minuten"
        -- 1v1-Duell
        duelId = nil,
        duelSide = nil,         -- 1 = Herausforderer, 2 = Herausgeforderter
        lastDuelChallenge = -1000000,
        caseBusyUntil = 0,
        lastVehicle = 0,
        vehicleNet = nil,       -- ausgeparktes Auto (Netzwerk-ID)
    }
end

function PlayerByUserId(uid)
    uid = Util.int(uid)
    for _, p in pairs(Players) do
        if p.acc and p.acc.id == uid then return p end
    end
    return nil
end

function OnlineCount()
    local n = 0
    for _, p in pairs(Players) do
        if p.loggedIn then n = n + 1 end
    end
    return n
end

-- IsAdmin(src) steht in server/admin.lua

-- Eingeloggter Spieler + Spam-Schutz für Menü-Aktionen (max. 10 in 2 Sekunden)
function Guard(src)
    local p = Players[src]
    if not p or not p.loggedIn or not p.acc then return nil end
    local t = Now()
    if t - p.lastAction > 2000 then
        p.lastAction, p.actionCount = t, 0
    end
    p.actionCount = p.actionCount + 1
    if p.actionCount > 10 then return nil end
    return p
end

function Notify(target, kind, text)
    TriggerClientEvent('bspvp:notify', target, kind, text)
end

-- System-Zeile im Chat (^1 … ^9 = Farben wie im normalen FiveM-Chat)
function Chat(target, msg)
    TriggerClientEvent('bspvp:chat', target, { kind = 'system', text = tostring(msg) })
end

function Announce(target, text)
    TriggerClientEvent('bspvp:announce', target, text)
end

function Reply(src, msg)
    if src == 0 then print((tostring(msg):gsub('%^%d', ''))) else Chat(src, msg) end
end

function SendVitals(p)
    TriggerClientEvent('bspvp:vitals', p.src, p.hp, p.armour)
end

function DisplayName(p)
    if p and p.acc then return p.acc.name end
    return p and (GetPlayerName(p.src) or '?') or '?'
end
