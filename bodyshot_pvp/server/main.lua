-- =======================================================================
--  Start
-- =======================================================================

CreateThread(function()
    DB.init()
    Accounts.loadAll()
    Teams.loadAll()
    Hoods.load()
    Gangwar.loadZones()
    Bounty.load()

    if Config.World and Config.World.disableNPCs then
        SetRoutingBucketPopulationEnabled(0, false)                  -- Hoods
        for i in ipairs(Config.Arenas) do
            SetRoutingBucketPopulationEnabled(FFA.bucket(i), false)  -- FFA-Arenen
        end
    end

    if GetResourceState('chat') == 'started' then
        print('^3[bodyshot_pvp] Der Standard-Chat (Resource "chat") läuft noch. Nimm "ensure chat" aus der server.cfg – der Server hat seinen eigenen Chat (T).^7')
    end
    if GetConvar('onesync', 'off') == 'off' then
        print('^1[bodyshot_pvp] OneSync ist AUS! Ohne OneSync zählt kein Treffer. In txAdmin unter Settings > FXServer aktivieren oder "set onesync on" in die server.cfg.^7')
    end

    local accounts, teams = 0, 0
    for _ in pairs(Accounts.byId) do accounts = accounts + 1 end
    for _ in pairs(Teams.private) do teams = teams + 1 end

    print(('^2[%s]^7 %d Accounts, %d private Teams, %d Gebiete, %d FFA-Arenen geladen'):format(Config.ServerName, accounts, teams, #Config.Zones, #Config.Arenas))
    if GetConvarInt and GetConvarInt('sv_enforceGameBuild', 0) < 2545 then
        print('^3[bodyshot_pvp] Tipp: "sv_enforceGameBuild 3095" in die server.cfg – dann gibt es die neuen Outfits und Autos.^7')
    end
    print(('^2[%s]^7 Bodyshot-System: %d HP + %d Weste = %d pro Leben'):format(Config.ServerName, Config.MaxHealth, Config.MaxArmour, Weapons.pool))
    for _, w in ipairs(Weapons.list) do
        local warn = ''
        if w.shots and w.realShots ~= w.shots then
            warn = (' ^3(gewünscht %d – mit ganzen Zahlen nicht exakt möglich)^7'):format(w.shots)
        end
        local price = w.price > 0 and ('$' .. Util.formatMoney(w.price)) or 'Start'
        print(('  %-24s %3d Schaden  ->  %2d Treffer   %s%s'):format(w.label, w.damage, w.realShots, price, warn))
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, p in pairs(Players) do
        if p.acc then Accounts.save(p.acc) end
    end
    Gangwar.saveZones()
    DB.flush(true)                 -- MySQL: letzte Änderungen sofort schicken
end)
