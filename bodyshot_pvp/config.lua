Config = {}

--[[ =======================================================================
     GANGWAR (Bodyshot) – Einstellungen
     Alles, was du anpassen willst, steht in dieser Datei.
     Nach einer Änderung: in der txAdmin-Konsole "ensure bodyshot_pvp"
     eingeben oder den Server neu starten.
======================================================================= ]]

-- Logo oben links in jedem Menü: großer Name + blaue Box daneben
Config.ServerName = 'BODYSHOT'
Config.ServerTag  = 'GANGWAR'
Config.Welcome    = 'Willkommen! Hier kämpfen Gangs um Los Santos – nur mit Langwaffen und mit Bodyshot-System. Wähl dein Team, hol dir deine Waffen und erobere die Stadt Gebiet für Gebiet.'

-- Links für Ladebildschirm und Verbinden-Karte (leer lassen = Button ausblenden)
Config.Links = {
    discord = 'https://discord.gg/p24Wzcqqpp',
    store   = '',                                   -- z. B. https://deinserver.tebex.io
}

-- Tasten (Spieler können sie in den FiveM-Einstellungen unter "Key Bindings" ändern)
Config.Keys = {
    teams  = 'F1',     -- Team-Auswahl
    menu   = 'F2',     -- Hauptmenü
    repair = 'F3',     -- Fahrzeug reparieren (nicht im FFA/Gangwar)
    admin  = 'F6',     -- Admin-Menü (nur mit Recht)
    chat   = 'T',      -- Chat
    interact = 'E',    -- Garage an der Hood
    duelAccept  = 'Y', -- Duell-Herausforderung annehmen
    duelDecline = 'X', -- Duell-Herausforderung ablehnen
}


-- -----------------------------------------------------------------------
--  DATENBANK
-- -----------------------------------------------------------------------
-- 'auto'  = MySQL über oxmysql, wenn oxmysql läuft – sonst Resource-KVP
-- 'mysql' = nur MySQL (Spieler kommen erst rein, wenn die DB erreichbar ist)
-- 'kvp'   = ohne Datenbank (wie v3)
-- Einrichten: bodyshot.sql importieren, oxmysql installieren, in der server.cfg
--   set mysql_connection_string "mysql://user:passwort@localhost/bodyshot?charset=utf8mb4"
--   ensure oxmysql      (VOR ensure bodyshot_pvp)
-- Beim ersten Start mit leerer Datenbank werden die alten KVP-Daten übernommen.
Config.Database = {
    mode = 'auto',
}


-- -----------------------------------------------------------------------
--  VERBINDEN – Karte, die beim Joinen angezeigt wird
-- -----------------------------------------------------------------------
Config.Connect = {
    enabled = true,
    seconds = 5,                 -- Countdown, bevor es weitergeht
    title   = 'Aufnahmepflicht',
    text    = {
        { flag = 'DE', lang = 'Deutsch', text = 'Auf diesem Server gilt eine permanente Aufnahmepflicht. Wenn du gebannt wirst und keinen Clip vorlegen kannst, wirst du nicht entbannt.' },
        { flag = 'GB', lang = 'English', text = 'Permanent recording is mandatory on this server. If you get banned and cannot provide a clip, you will not be unbanned.' },
    },
}

-- Regelwerk (Seite im Hauptmenü)
Config.Rules = {
    'Kein Cheaten, keine Mod-Menüs, keine Makros.',
    'Aufnahmepflicht: Nimm dein Gameplay auf. Ohne Clip keine Entbannung.',
    'Kein Bugusing, kein Glitchen in Wände oder Dächer.',
    'Respektvoller Umgang im Chat – keine Beleidigungen, kein Spam.',
    'Teams nicht absprechen (kein Teaming im FFA).',
    'Admins haben das letzte Wort.',
}

-- Ladebildschirm: Untertitel in Schreibschrift unter dem Logo.
-- Eigenes Bild rechts: html/loading/img/character.png  |  Eigenes Logo: html/img/logo.png
Config.LoadingSubtitle = 'Los Santos gehört den Gangs'

-- Musik im Ladebildschirm: MP3s nach html/loading/music/ legen und hier eintragen
Config.Music = {
    volume = 0.25,
    tracks = {
        -- { title = 'Mein Song', artist = 'Ich', file = 'meinsong.mp3' },
    },
}


-- -----------------------------------------------------------------------
--  ACCOUNTS & LOGIN
-- -----------------------------------------------------------------------
-- Login läuft über den Rockstar-Account (keine Passwörter nötig).
-- Beim ersten Join wählt man einen Namen und bekommt eine User-ID (ab 0).
Config.Accounts = {
    startMoney = 2500,
    nameMin    = 3,
    nameMax    = 16,
}

-- Kamera hinter der Modus-Auswahl (dreht sich langsam über der Stadt)
Config.LoginCam = {
    center = vector3(-60.0, -820.0, 120.0),      -- Downtown
    radius = 420.0,
    height = 230.0,
    speed  = 1.5,                                -- Grad pro Sekunde
}


-- -----------------------------------------------------------------------
--  LEBEN & WESTE  (Bodyshot-System)
-- -----------------------------------------------------------------------
-- Treffer gehen zuerst auf die Weste, danach aufs Leben.
-- Kopf, Körper, Arme und Beine machen GLEICH viel Schaden (= Bodyshot).
Config.MaxHealth   = 100
Config.MaxArmour   = 100
Config.SpawnArmour = 100


-- -----------------------------------------------------------------------
--  WAFFEN  –  nur diese Waffen machen Schaden ("nur Langwaffen")
-- -----------------------------------------------------------------------
-- shots = Treffer bis zum Tod (von voller HP + voller Weste)
-- price = Preis im Waffenshop. 0 = Startwaffe (hat jeder sofort).
-- Gekaufte Waffen bleiben für immer im Loadout.
Config.Weapons = {
    { name = 'WEAPON_COMPACTRIFLE',       label = 'Compact Rifle',         shots = 17, price = 0 },
    { name = 'WEAPON_ASSAULTRIFLE',       label = 'Assault Rifle',         shots = 17, price = 0 },
    { name = 'WEAPON_CARBINERIFLE',       label = 'Carbine Rifle',         shots = 17, price = 7500 },
    { name = 'WEAPON_BULLPUPRIFLE',       label = 'Bullpup Rifle',         shots = 17, price = 9000 },
    { name = 'WEAPON_GUSENBERG',          label = 'Gusenberg Sweeper',     shots = 17, price = 10000 },
    { name = 'WEAPON_ADVANCEDRIFLE',      label = 'Advanced Rifle',        shots = 16, price = 12500 },
    { name = 'WEAPON_SPECIALCARBINE',     label = 'Special Carbine',       shots = 16, price = 15000 },
    { name = 'WEAPON_ASSAULTRIFLE_MK2',   label = 'Assault Rifle Mk II',   shots = 15, price = 25000 },
    { name = 'WEAPON_CARBINERIFLE_MK2',   label = 'Carbine Rifle Mk II',   shots = 15, price = 30000 },
    { name = 'WEAPON_BULLPUPRIFLE_MK2',   label = 'Bullpup Rifle Mk II',   shots = 15, price = 30000 },
    { name = 'WEAPON_SPECIALCARBINE_MK2', label = 'Special Carbine Mk II', shots = 14, price = 45000 },

    -- Neuere Gewehre (Gamebuild 3095 ist in der server.cfg schon gesetzt)
    -- { name = 'WEAPON_MILITARYRIFLE', label = 'Military Rifle',  shots = 16, price = 20000 },
    -- { name = 'WEAPON_HEAVYRIFLE',    label = 'Heavy Rifle',     shots = 16, price = 20000 },
    -- { name = 'WEAPON_TACTICALRIFLE', label = 'Service Carbine', shots = 16, price = 20000 },
}

Config.Ammo = {
    amount       = 750,
    infinite     = true,   -- unendlich Reserve (nachladen muss man trotzdem)
    refillOnKill = true,
}

Config.BlockOtherWeapons = true   -- Pistolen, Fäuste, Messer usw. machen 0 Schaden
Config.DisableMelee      = true
Config.ZoneMultiplier    = { head = 1.0, torso = 1.0, arms = 1.0, legs = 1.0 }  -- Bodyshot: alles 1.0
Config.ArmourAbsorb      = 1.0
Config.EnvironmentDamage = 1.0    -- Fallschaden (0 = aus)
Config.MaxHitDistance    = 350.0
Config.MaxHitsPerSecond  = 20
Config.KillCreditSeconds = 10
Config.SpawnProtectionSeconds = 3


-- -----------------------------------------------------------------------
--  GELD & XP
-- -----------------------------------------------------------------------
Config.Rewards = {
    hoodKill    = { money = 100,  xp = 50 },     -- Kill an den Hoods
    ffaKill     = { money = 150,  xp = 100 },
    gangwarKill = { money = 250,  xp = 150 },
    gangwarWin  = { money = 3000, xp = 1000 },
    gangwarLoss = { money = 750,  xp = 300 },
}

-- Spielzeit-Bonus (unten rechts im HUD): alle X Minuten Spielzeit gibt es Geld
Config.PlaytimeReward = {
    minutes = 60,
    money   = 1000,
    xp      = 0,
}


-- -----------------------------------------------------------------------
--  OUTFITS  –  Freemode-Charakter in der Farbe seines Teams
-- -----------------------------------------------------------------------
-- Jedes Kleidungsstück hat mehrere Varianten: genommen wird die erste, die
-- es im Spiel gibt (die neue Kleidung braucht Gamebuild 3095, die alte
-- gibt es immer). Die Zahlen bei "colors" sind die Texturen pro Variante.
Config.Outfits = {
    items = {
        top   = { component = 11, variants = { { drawable = 384, torso = 4 }, { drawable = 7, torso = 4 } } },  -- Hoodie
        legs  = { component = 4,  variants = { { drawable = 173 }, { drawable = 3 } } },                       -- Jogger
        shoes = { component = 6,  variants = { { drawable = 116 }, { drawable = 7 } } },                       -- Sneaker
        hat   = { prop = 0, chance = 0.6, variants = { { drawable = 181 }, { drawable = 14 } } },               -- Cap / Bandana
    },
    undershirt = 15,      -- kein Unterhemd
    colors = {
        --          Hoodie         Jogger         Sneaker         Cap
        green  = { top = { 19, 6 },  legs = { 0, 2 }, shoes = { 19, 8 },  hat = { 19, 4 } },
        purple = { top = { 25, 9 },  legs = { 0, 2 }, shoes = { 24, 14 }, hat = { 24, 5 } },
        yellow = { top = { 10, 8 },  legs = { 0, 2 }, shoes = { 11, 11 }, hat = { 11, 7 } },
        cyan   = { top = { 15, 3 },  legs = { 0, 2 }, shoes = { 15, 0 },  hat = { 15, 0 } },
        blue   = { top = { 13, 4 },  legs = { 0, 2 }, shoes = { 12, 10 }, hat = { 12, 2 } },
        gray   = { top = { 1, 1 },   legs = { 0, 2 }, shoes = { 0, 2 },   hat = { 0, 1 } },
        red    = { top = { 8, 5 },   legs = { 0, 2 }, shoes = { 8, 9 },   hat = { 8, 3 } },
        white  = { top = { 3, 0 },   legs = { 0, 2 }, shoes = { 3, 0 },   hat = { 3, 0 } },
        orange = { top = { 9, 7 },   legs = { 0, 2 }, shoes = { 9, 7 },   hat = { 9, 1 } },
        teal   = { top = { 14, 3 },  legs = { 0, 2 }, shoes = { 14, 0 },  hat = { 14, 0 } },
        pink   = { top = { 7, 12 },  legs = { 0, 2 }, shoes = { 7, 0 },   hat = { 7, 0 } },
        silver = { top = { 2, 1 },   legs = { 0, 2 }, shoes = { 2, 1 },   hat = { 2, 1 } },
    },
}


-- -----------------------------------------------------------------------
--  TEAMS – die Gangs aus GTA, jede mit eigener Hood
-- -----------------------------------------------------------------------
-- outfit = Farbe aus Config.Outfits.colors
-- blip   = Blip-Farbe auf der Karte
-- hood   = Spawnpunkt (spawn), Garage (garage, E drücken) und Auto-Punkt (car)
--          Im Spiel ändern: als Admin hinstellen und /sethood spawn|garage|car eingeben.
-- Eigenes Logo: html/img/teams/<id>.png (sonst wird ein Emblem erzeugt)
Config.TeamMax = 25      -- Spieler pro Team (0 = unbegrenzt)

Config.Gangs = {
    { id = 'families',  name = 'Families',        tag = 'FAM', color = '#2ecc40', blip = 2,  outfit = 'green',
      hood = { name = 'Grove Street',          spawn = vector4(99.5, -1936.0, 20.8, 31.0),    garage = vector3(93.1, -1925.1, 19.8),   car = vector4(90.4, -1928.1, 20.3, 49.0) } },
    { id = 'ballas',    name = 'Ballas',          tag = 'BAL', color = '#a335ee', blip = 27, outfit = 'purple',
      hood = { name = 'Brouge Avenue',         spawn = vector4(157.8, -1788.5, 29.2, 121.0),  garage = vector3(147.0, -1795.1, 28.0),  car = vector4(150.0, -1797.7, 28.5, 140.0) } },
    { id = 'vagos',     name = 'Vagos',           tag = 'VAG', color = '#ffd400', blip = 5,  outfit = 'yellow',
      hood = { name = 'Jamestown Street',      spawn = vector4(305.8, -1991.2, 21.5, 303.0),  garage = vector3(316.3, -1984.3, 21.1),  car = vector4(313.2, -1981.8, 21.6, 322.0) } },
    { id = 'aztecas',   name = 'Aztecas',         tag = 'AZT', color = '#00c8e6', blip = 3,  outfit = 'cyan',
      hood = { name = 'Innocence Boulevard',   spawn = vector4(439.8, -1603.8, 29.3, 211.0),  garage = vector3(446.3, -1614.6, 28.3),  car = vector4(448.9, -1611.5, 28.8, 230.0) } },
    { id = 'marabunta', name = 'Marabunta',       tag = 'MAR', color = '#2f6bff', blip = 38, outfit = 'blue',
      hood = { name = 'El Burro Heights',      spawn = vector4(1282.8, -1580.8, 51.7, 107.0), garage = vector3(1270.6, -1584.4, 51.3), car = vector4(1273.0, -1587.7, 51.8, 125.0) } },
    { id = 'lost',      name = 'Lost MC',         tag = 'LMC', color = '#9aa0a6', blip = 40, outfit = 'gray',
      hood = { name = 'Clubhouse',             spawn = vector4(967.8, -127.8, 74.3, 223.0),   garage = vector3(976.4, -137.0, 73.1),   car = vector4(978.3, -133.4, 73.6, 242.0) } },
    { id = 'triaden',   name = 'Triaden',         tag = 'TRI', color = '#ff3b3b', blip = 1,  outfit = 'red',
      hood = { name = 'Raven Slaughterhouse',  spawn = vector4(924.2, -2147.0, 30.2, 337.0),  garage = vector3(929.2, -2135.4, 29.3),  car = vector4(925.2, -2135.0, 29.8, 355.0) } },
    { id = 'kartell',   name = 'Madrazo-Kartell', tag = 'MAD', color = '#f2f2f2', blip = 0,  outfit = 'white',
      hood = { name = 'La Fuente Blanca',      spawn = vector4(1404.0, 1117.2, 114.8, 72.0),  garage = vector3(1392.0, 1121.2, 113.8), car = vector4(1392.0, 1117.2, 114.3, 90.0) } },
}

-- Private Teams: Spieler gründen ihr eigenes Team und laden andere per User-ID ein
Config.PrivateTeams = {
    enabled    = true,
    price      = 25000,
    maxMembers = 15,
    -- Farbe -> Outfit-Farbe
    colors = {
        { hex = '#ff3b3b', outfit = 'red' },    { hex = '#ff8c1a', outfit = 'orange' },
        { hex = '#ffd400', outfit = 'yellow' }, { hex = '#33cc66', outfit = 'green' },
        { hex = '#1ec8c8', outfit = 'teal' },   { hex = '#2f80ff', outfit = 'blue' },
        { hex = '#8a5cff', outfit = 'purple' }, { hex = '#ff4fa3', outfit = 'pink' },
        { hex = '#f2f2f2', outfit = 'white' },  { hex = '#8c8c8c', outfit = 'silver' },
    },
    -- Hoods für private Teams (werden reihum verteilt)
    hoods = {
        { name = 'Legion Square', spawn = vector4(222.2, -844.8, 30.3, 231.0),  garage = vector3(232.1, -852.7, 29.0),  car = vector4(233.5, -848.9, 29.5, 250.0) },
        { name = 'Mirror Park',   spawn = vector4(1177.5, -628.5, 63.1, 353.0), garage = vector3(1179.1, -616.0, 62.4), car = vector4(1175.2, -616.7, 62.9, 11.0) },
        { name = 'Sandy Shores',  spawn = vector4(1867.2, 3670.0, 33.8, 101.0), garage = vector3(1854.8, 3667.5, 33.1), car = vector4(1856.8, 3664.0, 33.6, 120.0) },
        { name = 'Paleto Bay',    spawn = vector4(-181.2, 6444.8, 31.1, 301.0), garage = vector3(-170.4, 6451.2, 30.0), car = vector4(-173.4, 6453.8, 30.5, 319.0) },
    },
}

-- An den Hoods wird gekämpft: jeder hat seine Waffen dabei und kann auf
-- Spieler ANDERER Teams schießen (Teamkameraden nicht).
-- false = Hood ist wieder Safezone (niemand kann schießen)
Config.HoodCombat = true
Config.HoodRespawnSeconds = 3
Config.HoodRadius = 60.0

-- Fallback-Spawn, falls ein Team keine Hood hat
Config.Lobby = {
    center = vector3(222.20, -864.02, 30.29),    -- Legion Square
    radius = 35.0,
}


-- -----------------------------------------------------------------------
--  GARAGE AN DER HOOD
-- -----------------------------------------------------------------------
-- level = ab welchem Battlepass-Level das Auto frei ist
-- Autos werden in der Teamfarbe lackiert. Bilder kommen automatisch.
Config.Garage = {
    enabled  = true,
    cooldown = 10,                 -- Sekunden zwischen zwei Autos
    repairCooldown = 30,           -- F3: Sekunden zwischen zwei Reparaturen
    vehicles = {
        { model = 'bf400',    label = 'BF400',              level = 1 },
        { model = 'remus',    label = 'Remus',              level = 1 },
        { model = 'sentinel', label = 'Sentinel XS',        level = 1 },
        { model = 'growler',  label = 'Growler',            level = 3 },
        { model = 'issi7',    label = 'Issi Sport',         level = 5 },
        { model = 'feltzer2', label = 'Feltzer',            level = 8 },
        { model = 'elegy',    label = 'Elegy Retro Custom', level = 10 },
        { model = 'jester',   label = 'Jester',             level = 14 },
        { model = 'sultan2',  label = 'Sultan Classic',     level = 15 },
        { model = 'kuruma',   label = 'Kuruma',             level = 18 },
        { model = 'comet2',   label = 'Comet',              level = 22 },
        { model = 'zentorno', label = 'Zentorno',           level = 28 },
    },
}


-- -----------------------------------------------------------------------
--  FFA  –  mehrere Arenen gleichzeitig, jede mit Spieler-Limit
-- -----------------------------------------------------------------------
Config.FFA = {
    respawnSeconds = 3,
    killReward     = { health = 100, armour = 100 },   -- nach jedem Kill (max. voll)
}

Config.OutOfZoneSeconds = 5

-- Eigenes Vorschaubild: html/img/ffa/<key>.jpg
-- Eigene Spawnpunkte: im Spiel /pvpcoords eingeben und bei "spawns" eintragen
Config.Arenas = {
    { key = 'hafen',     name = 'Hafen',           center = vector3(486.42, -3339.69, 6.07),  radius = 75.0, max = 16 },
    { key = 'jetsam',    name = 'Jetsam Terminal', center = vector3(760.40, -2943.20, 5.80),  radius = 80.0, max = 16 },
    { key = 'flugplatz', name = 'Sandy Flugplatz', center = vector3(1747.00, 3273.70, 41.10), radius = 90.0, max = 16 },
    { key = 'legion',    name = 'Legion Square',   center = vector3(196.00, -933.00, 30.00),  radius = 55.0, max = 12 },
    { key = 'davis',     name = 'Davis',           center = vector3(38.00, -1846.00, 23.70),  radius = 65.0, max = 12 },
    { key = 'jamestown', name = 'Jamestown',       center = vector3(306.00, -1991.00, 21.50), radius = 60.0, max = 12 },
    { key = 'sandy',     name = 'Sandy Shores',    center = vector3(1848.00, 3681.00, 34.50), radius = 70.0, max = 12 },
    { key = 'paleto',    name = 'Paleto Bay',      center = vector3(-162.00, 6434.00, 32.00), radius = 70.0, max = 12 },
}


-- -----------------------------------------------------------------------
--  GANGWAR
-- -----------------------------------------------------------------------
-- Ablauf: Ein Team greift ein Gebiet an -> Wartephase -> Kampf.
-- Jedes Gebiet ist eine Bubble (Kuppel) auf der Straße. Beide Teams spawnen
-- auf der Straße außerhalb der Bubble, auf GEGENÜBERLIEGENDEN Seiten.
-- Am Spawn parkst du mit E ein Gangwar-Auto aus und fährst in die Bubble.
-- Geschossen wird nur IN der Bubble, nur Kills in der Bubble geben Punkte.
-- Wer am Ende mehr Punkte hat, gewinnt. Gewinnen die Angreifer, gehört
-- ihnen das Gebiet.
Config.Gangwar = {
    spawnDistance       = 260.0,  -- so weit liegen die Team-Spawns von der Mitte der Bubble weg
    boundaryExtra       = 130.0,  -- Spielfeld = spawnDistance + das hier, weiter weg = zurück zum Spawn
    garageRange         = 130.0,  -- so nah muss man am eigenen Spawn sein, um auszuparken
    -- Autos an der Gangwar-Garage (für alle frei, ohne Level)
    vehicles = {
        { model = 'sultan',    label = 'Sultan' },
        { model = 'kuruma',    label = 'Kuruma' },
        { model = 'schafter2', label = 'Schafter' },
        { model = 'baller2',   label = 'Baller' },
        { model = 'buffalo',   label = 'Buffalo' },
        { model = 'bf400',     label = 'BF400' },
    },
    prepareSeconds      = 60,     -- Wartephase (kein Schaden) – Zeit zum Ausparken und Hinfahren
    fightMinutes        = 10,     -- Kampfzeit
    cooldownMinutes     = 30,     -- danach kann das Gebiet so lange nicht angegriffen werden
    pointsPerKill       = 3,
    attackerStartPoints = 1,      -- Angreifer starten mit 1 Punkt
    respawnSeconds      = 5,
    killReward          = { health = 0, armour = 0 },   -- im Gangwar kein Heilen pro Kill
    minDefendersOnline  = 0,      -- so viele Verteidiger müssen online sein (0 = egal)
    privateLeaderOnly   = true,   -- bei privaten Teams darf nur der Leader angreifen
    incomeMinutes       = 15,     -- alle X Minuten bekommt jeder Spieler eines Teams Geld ...
    incomePerZone       = 500,    -- ... so viel pro Gebiet, das seinem Team gehört
}

-- Gebiete = Bubbles auf der Straße. center = Mitte auf Straßenhöhe, radius = Größe der Bubble.
-- spawnAngle = Richtung, aus der die Angreifer kommen (0 = Norden, 90 = Osten, 180 = Süden, 270 = Westen).
-- Die Verteidiger spawnen auf der gegenüberliegenden Seite. Der Spawn wird automatisch
-- auf die nächste Straße gesetzt (nie auf Dächer). Eigene Punkte gehen auch:
--   attackerSpawn = vector3(...), defenderSpawn = vector3(...)   (mit /pvpcoords ablesen)
-- owner      = Gang, der das Gebiet am Anfang gehört (nil = frei)
Config.Zones = {
    { key = 'legion',     name = 'Legion Square',      center = vector3(195.00, -933.00, 30.00),   radius = 110.0, owner = 'ballas',    spawnAngle = 0 },
    { key = 'vinewood',   name = 'Vinewood Boulevard', center = vector3(362.00, 137.00, 102.10),   radius = 110.0, owner = 'families',  spawnAngle = 90 },
    { key = 'mirrorpark', name = 'Mirror Park',        center = vector3(1176.00, -475.00, 65.10),  radius = 110.0, owner = 'vagos',     spawnAngle = 90 },
    { key = 'vespucci',   name = 'Magellan Avenue',    center = vector3(-1165.00, -1468.00, 3.50), radius = 110.0, owner = 'aztecas',   spawnAngle = 45 },
    { key = 'strawberry', name = 'Strawberry Avenue',  center = vector3(135.00, -1307.00, 29.20),  radius = 110.0, owner = 'marabunta', spawnAngle = 0 },
    { key = 'docks',      name = 'Buccaneer Way',      center = vector3(996.00, -3000.00, 5.00),   radius = 120.0, owner = 'lost',      spawnAngle = 90 },
    { key = 'grapeseed',  name = 'Grapeseed Main St',  center = vector3(1664.00, 4896.00, 41.10),  radius = 120.0, owner = nil,         spawnAngle = 0 },
    { key = 'paleto',     name = 'Paleto Bay',         center = vector3(-148.00, 6333.00, 30.60),  radius = 120.0, owner = nil,         spawnAngle = 45 },
}


-- -----------------------------------------------------------------------
--  BATTLEPASS
-- -----------------------------------------------------------------------
-- XP gibt es für Kills und Gangwars. Belohnungen holt man im Menü ab.
-- Premium-Spieler vergibst du im Admin-Menü (F6) oder mit /premium <User-ID>.
-- Belohnung: { money = Betrag }, { weapon = 'WEAPON_...' } oder { case = 'street' | 'mk2' | 'gold' }
-- (Waffe schon im Besitz -> stattdessen duplicateMoney)
Config.Battlepass = {
    season         = 1,
    name           = 'Season 1',
    xpPerLevel     = 1000,
    duplicateMoney = 5000,
    rewards = {
        [1]  = { free = { money = 500 },                          premium = { money = 2500 } },
        [2]  = { free = { money = 750 },                          premium = { money = 2500 } },
        [3]  = { free = { money = 1000 },                         premium = { weapon = 'WEAPON_CARBINERIFLE' } },
        [4]  = { free = { case = 'street' },                      premium = { money = 3000 } },
        [5]  = { free = { weapon = 'WEAPON_CARBINERIFLE' },       premium = { money = 5000 } },
        [6]  = { free = { money = 1500 },                         premium = { money = 3000 } },
        [7]  = { free = { money = 1500 },                         premium = { weapon = 'WEAPON_ADVANCEDRIFLE' } },
        [8]  = { free = { money = 2000 },                         premium = { money = 4000 } },
        [9]  = { free = { money = 2000 },                         premium = { case = 'mk2' } },
        [10] = { free = { weapon = 'WEAPON_BULLPUPRIFLE' },       premium = { weapon = 'WEAPON_ASSAULTRIFLE_MK2' } },
        [11] = { free = { money = 2500 },                         premium = { money = 5000 } },
        [12] = { free = { case = 'street' },                      premium = { money = 5000 } },
        [13] = { free = { money = 3000 },                         premium = { money = 5000 } },
        [14] = { free = { money = 3000 },                         premium = { money = 6000 } },
        [15] = { free = { weapon = 'WEAPON_ADVANCEDRIFLE' },      premium = { weapon = 'WEAPON_SPECIALCARBINE' } },
        [16] = { free = { money = 3500 },                         premium = { money = 6000 } },
        [17] = { free = { money = 3500 },                         premium = { case = 'mk2' } },
        [18] = { free = { money = 4000 },                         premium = { money = 7000 } },
        [19] = { free = { money = 4000 },                         premium = { money = 7000 } },
        [20] = { free = { weapon = 'WEAPON_SPECIALCARBINE' },     premium = { weapon = 'WEAPON_CARBINERIFLE_MK2' } },
        [21] = { free = { money = 4500 },                         premium = { money = 8000 } },
        [22] = { free = { case = 'mk2' },                         premium = { money = 8000 } },
        [23] = { free = { money = 5000 },                         premium = { money = 8000 } },
        [24] = { free = { money = 5000 },                         premium = { money = 9000 } },
        [25] = { free = { weapon = 'WEAPON_ASSAULTRIFLE_MK2' },   premium = { weapon = 'WEAPON_BULLPUPRIFLE_MK2' } },
        [26] = { free = { money = 6000 },                         premium = { money = 10000 } },
        [27] = { free = { money = 6000 },                         premium = { case = 'gold' } },
        [28] = { free = { money = 7000 },                         premium = { money = 12000 } },
        [29] = { free = { money = 8000 },                         premium = { money = 15000 } },
        [30] = { free = { weapon = 'WEAPON_CARBINERIFLE_MK2' },   premium = { weapon = 'WEAPON_SPECIALCARBINE_MK2' } },
    },
}


-- =======================================================================
--  NEU IN v4: TÄGLICHE MISSIONEN, CASES & SKINS, 1v1-DUELLE, KOPFGELD
-- =======================================================================

-- -----------------------------------------------------------------------
--  TÄGLICHE MISSIONEN + LOGIN-BONUS  (F2 → Täglich)
-- -----------------------------------------------------------------------
-- Jeden Tag (Serverzeit, ab 00:00) bekommt jeder Spieler 3 Missionen aus der
-- Liste. Wer alle 3 schafft, bekommt zusätzlich den Bonus.
-- stat: kill, ffaKill, gwKill, hit, streak (beste Serie), gwPlayed, gwWin,
--       duelPlayed, duelWin, bountyClaim, bountyPlace, caseOpen, minutes
Config.Missions = {
    enabled = true,
    perDay  = 3,
    allDoneBonus = { money = 2500, case = 'street' },
    list = {
        { id = 'kills',     text = 'Hol %d Kills',                   stat = 'kill',        goal = 25,  money = 1500, xp = 300 },
        { id = 'ffa',       text = 'Hol %d Kills im FFA',            stat = 'ffaKill',     goal = 20,  money = 1500, xp = 300 },
        { id = 'gwkills',   text = 'Hol %d Kills im Gangwar',        stat = 'gwKill',      goal = 8,   money = 2500, xp = 500 },
        { id = 'gwplay',    text = 'Kämpf in %d Gangwar mit',        stat = 'gwPlayed',    goal = 1,   money = 2000, xp = 400 },
        { id = 'gwwin',     text = 'Gewinn %d Gangwar',              stat = 'gwWin',       goal = 1,   money = 3500, xp = 700 },
        { id = 'streak',    text = 'Schaff eine %der-Killserie',     stat = 'streak',      goal = 5,   money = 2000, xp = 400 },
        { id = 'hits',      text = 'Triff %d Mal',                   stat = 'hit',         goal = 250, money = 1000, xp = 250 },
        { id = 'duelplay',  text = 'Spiel %d 1v1-Duelle',            stat = 'duelPlayed',  goal = 2,   money = 1500, xp = 300 },
        { id = 'duelwin',   text = 'Gewinn %d 1v1-Duell',            stat = 'duelWin',     goal = 1,   money = 2500, xp = 500 },
        { id = 'bounty',    text = 'Kassier %d Kopfgeld',            stat = 'bountyClaim', goal = 1,   money = 2500, xp = 500 },
        { id = 'case',      text = 'Öffne %d Case',                  stat = 'caseOpen',    goal = 1,   money = 1000, xp = 200 },
        { id = 'play',      text = 'Spiel %d Minuten',               stat = 'minutes',     goal = 45,  money = 1500, xp = 300 },
    },
}

-- Login-Bonus: jeden Tag einloggen = Serie. Einen Tag verpasst = wieder Tag 1.
-- Nach Tag 7 geht es wieder bei Tag 1 los (die Serie zählt aber weiter).
Config.LoginRewards = {
    { money = 1000 },
    { money = 1500 },
    { case = 'street' },
    { money = 2500 },
    { money = 3500 },
    { case = 'mk2' },
    { money = 5000, case = 'gold' },
}


-- -----------------------------------------------------------------------
--  CASES & WAFFEN-SKINS  (F2 → Cases)
-- -----------------------------------------------------------------------
-- Skins sind echte GTA-Lackierungen: Farbtöne für alle Gewehre, Mk-II-Farben
-- und Tarnmuster für Mk-II-Waffen und Luxus-Finishs. Einmal gezogen gehört der
-- Skin für immer. Doppelt gezogen = Geld zurück (duplicate).
-- weights = Chance pro Seltenheit (muss nicht 100 ergeben)
Config.Rarities = {
    { key = 'common',    name = 'Gewöhnlich', color = '#9fb3c8', duplicate = 1000 },
    { key = 'rare',      name = 'Selten',     color = '#3b9bff', duplicate = 2500 },
    { key = 'epic',      name = 'Episch',     color = '#b45cff', duplicate = 6000 },
    { key = 'legendary', name = 'Legendär',   color = '#ffb020', duplicate = 15000 },
}

Config.Cases = {
    { key = 'street', name = 'Street Case', price = 5000,  color = '#2f9bff', kinds = { 'tint' },
      weights = { common = 70, rare = 22, epic = 6.5, legendary = 1.5 } },
    { key = 'mk2',    name = 'Mk II Case',  price = 15000, color = '#b45cff', kinds = { 'mk2tint', 'camo' },
      weights = { common = 55, rare = 28, epic = 13, legendary = 4 } },
    -- Gold Case gibt es nur als Belohnung (Login-Tag 7, Battlepass) – price = 0
    { key = 'gold',   name = 'Gold Case',   price = 0,     color = '#ffb020', kinds = { 'tint', 'mk2tint', 'camo', 'finish' },
      weights = { epic = 70, legendary = 30 } },
}

Config.Skins = {
    -- Farbtöne der normalen Gewehre (Index aus GTA)
    tints = {
        { tint = 1, name = 'Grün',   rarity = 'common',    colors = { '#3d5a35', '#253a22' } },
        { tint = 4, name = 'Army',   rarity = 'common',    colors = { '#6b6646', '#45412c' } },
        { tint = 5, name = 'LSPD',   rarity = 'common',    colors = { '#2c3c5e', '#1b2539' } },
        { tint = 6, name = 'Orange', rarity = 'rare',      colors = { '#e2741d', '#8f4210' } },
        { tint = 3, name = 'Pink',   rarity = 'rare',      colors = { '#ee6fb4', '#9a3a6e' } },
        { tint = 7, name = 'Platin', rarity = 'epic',      colors = { '#eef2f5', '#9aa6b0' } },
        { tint = 2, name = 'Gold',   rarity = 'legendary', colors = { '#ffd86a', '#b8860b' } },
    },
    -- Mk-II-Farben (Index aus GTA)
    mk2Tints = {
        { tint = 1,  name = 'Klassisch Grau',      rarity = 'common',    colors = { '#7d8287', '#4a4e52' } },
        { tint = 3,  name = 'Klassisch Weiß',      rarity = 'common',    colors = { '#f0f0ec', '#b9bab4' } },
        { tint = 5,  name = 'Klassisch Grün',      rarity = 'common',    colors = { '#4c5d3c', '#2c3823' } },
        { tint = 6,  name = 'Klassisch Blau',      rarity = 'common',    colors = { '#3a5068', '#212f3e' } },
        { tint = 7,  name = 'Erdbraun',            rarity = 'common',    colors = { '#7a6248', '#4a3a29' } },
        { tint = 9,  name = 'Kontrast Rot',        rarity = 'rare',      colors = { '#d2312c', '#1d1d1f' } },
        { tint = 10, name = 'Kontrast Blau',       rarity = 'rare',      colors = { '#2f6fdc', '#1d1d1f' } },
        { tint = 11, name = 'Kontrast Gelb',       rarity = 'rare',      colors = { '#f2c230', '#1d1d1f' } },
        { tint = 13, name = 'Grell Pink',          rarity = 'rare',      colors = { '#ff4fb0', '#ff9fd6' } },
        { tint = 16, name = 'Grün und Lila',       rarity = 'epic',      colors = { '#3bd16f', '#8a3cf0' } },
        { tint = 19, name = 'Zyan-Details',        rarity = 'epic',      colors = { '#21d4e8', '#202428' } },
        { tint = 22, name = 'Blau und Weiß',       rarity = 'epic',      colors = { '#2c7cff', '#f4f6f8' } },
        { tint = 26, name = 'Metallic Lila-Grün',  rarity = 'epic',      colors = { '#7d3cff', '#9bf03c' } },
        { tint = 29, name = 'Metallic Blau',       rarity = 'epic',      colors = { '#4aa3ff', '#123a7a' } },
        { tint = 24, name = 'Metallic Platin',     rarity = 'legendary', colors = { '#ffffff', '#a8b4bf' } },
        { tint = 23, name = 'Metallic Gold',       rarity = 'legendary', colors = { '#ffe07a', '#b07a12' } },
    },
    -- Tarnmuster für Mk-II-Waffen (COMPONENT_<WAFFE>_MK2_CAMO...)
    camos = {
        { suffix = '',        name = 'Digital',       rarity = 'rare',      pattern = 'digital' },
        { suffix = '_02',     name = 'Pinselstrich',  rarity = 'rare',      pattern = 'brush' },
        { suffix = '_03',     name = 'Waldtarnung',   rarity = 'rare',      pattern = 'woodland' },
        { suffix = '_04',     name = 'Totenkopf',     rarity = 'epic',      pattern = 'skull' },
        { suffix = '_05',     name = 'Sessanta Nove', rarity = 'epic',      pattern = 'sessanta' },
        { suffix = '_06',     name = 'Perseus',       rarity = 'epic',      pattern = 'perseus' },
        { suffix = '_07',     name = 'Leopard',       rarity = 'epic',      pattern = 'leopard' },
        { suffix = '_08',     name = 'Zebra',         rarity = 'epic',      pattern = 'zebra' },
        { suffix = '_09',     name = 'Geometrie',     rarity = 'legendary', pattern = 'geometric' },
        { suffix = '_10',     name = 'Boom!',         rarity = 'legendary', pattern = 'boom' },
        { suffix = '_IND_01', name = 'Patriot',       rarity = 'legendary', pattern = 'patriot' },
    },
    -- Luxus-Finishs (ein Bauteil der Waffe)
    finishes = {
        WEAPON_ASSAULTRIFLE   = { component = 'COMPONENT_ASSAULTRIFLE_VARMOD_LUXE',       name = 'Yusuf Amir Luxus' },
        WEAPON_CARBINERIFLE   = { component = 'COMPONENT_CARBINERIFLE_VARMOD_LUXE',       name = 'Yusuf Amir Luxus' },
        WEAPON_ADVANCEDRIFLE  = { component = 'COMPONENT_ADVANCEDRIFLE_VARMOD_LUXE',      name = 'Vergoldetes Metall' },
        WEAPON_BULLPUPRIFLE   = { component = 'COMPONENT_BULLPUPRIFLE_VARMOD_LOW',        name = 'Vergoldetes Metall' },
        WEAPON_SPECIALCARBINE = { component = 'COMPONENT_SPECIALCARBINE_VARMOD_LOWRIDER', name = 'Graviertes Metall' },
    },
}


-- -----------------------------------------------------------------------
--  1v1-DUELLE  (F2 → Duelle oder /duell <User-ID>)
-- -----------------------------------------------------------------------
-- Eigene Welt, nur die beiden Spieler. Best of 3 (wer zuerst 2 Runden hat).
-- Beide spielen mit derselben Waffe (wählt der Herausforderer).
-- Einsatz: beide zahlen, der Gewinner bekommt alles + reward.
-- Duell-Kills zählen nicht für K/D, Kopfgeld oder Killserien.
Config.Duels = {
    enabled       = true,
    winRounds     = 2,          -- Best of 3
    roundSeconds  = 90,         -- danach gewinnt, wer mehr Leben + Weste hat
    countdown     = 3,
    inviteSeconds = 30,
    maxStake      = 50000,
    cooldown      = 15,         -- Sekunden zwischen zwei Herausforderungen
    radius        = 45.0,       -- Arena-Grenze um die Mitte
    reward        = { money = 500, xp = 250 },   -- Extra für den Gewinner
    announceStake = 5000,       -- ab diesem Einsatz wird der Sieg allen angesagt
    -- a und b = die beiden Startpunkte (echte Straßenpunkte aus GTA, ca. 35 m auseinander)
    arenas = {
        { key = 'vinewood',  name = 'Vinewood Boulevard', a = vector3(377.25, 131.25, 102.06),   b = vector3(346.50, 142.75, 102.06) },
        { key = 'mirror',    name = 'Mirror Park',        a = vector3(1159.50, -477.00, 65.09),  b = vector3(1194.00, -473.75, 65.06) },
        { key = 'docks',     name = 'Buccaneer Way',      a = vector3(1015.25, -3007.00, 4.88),  b = vector3(978.25, -2994.25, 4.88) },
        { key = 'vespucci',  name = 'Magellan Avenue',    a = vector3(-1155.00, -1483.25, 3.44), b = vector3(-1175.00, -1453.25, 3.44) },
        { key = 'grapeseed', name = 'Grapeseed Main St',  a = vector3(1665.75, 4878.25, 41.06),  b = vector3(1663.25, 4914.00, 41.09) },
        { key = 'paleto',    name = 'Pyrite Avenue',      a = vector3(-135.50, 6320.50, 30.56),  b = vector3(-160.75, 6346.00, 30.59) },
    },
}


-- -----------------------------------------------------------------------
--  KOPFGELD  (F2 → Kopfgeld oder /kopfgeld <User-ID> <Betrag>)
-- -----------------------------------------------------------------------
-- Spieler setzen Geld auf andere. Wer den Gesuchten im FFA oder Gangwar
-- tötet, kassiert alles. Lange Killserien bekommen automatisch ein Kopfgeld.
Config.Bounty = {
    enabled  = true,
    min      = 1000,
    max      = 100000,
    streak   = { [5] = 1000, [10] = 2500, [15] = 5000, [20] = 10000 },  -- automatisch (vom Server bezahlt)
    announce = 5000,            -- ab dieser Summe wird es allen angesagt
    marker   = true,            -- Kopfgeld über dem Kopf anzeigen (bis 80 m)
}


-- -----------------------------------------------------------------------
--  CHAT
-- -----------------------------------------------------------------------
Config.Chat = {
    maxLength   = 150,
    rateCount   = 3,          -- höchstens so viele Nachrichten ...
    rateSeconds = 4,          -- ... in so vielen Sekunden
    fadeSeconds = 10,         -- Nachrichten verblassen nach X Sekunden
    welcome = {               -- Zeilen nach dem Login
        'F1 = Teams',
        'F2 = Hauptmenü',
        'F3 = Fahrzeug reparieren',
    },
}


-- -----------------------------------------------------------------------
--  WELT & HUD
-- -----------------------------------------------------------------------
Config.World = {
    disableNPCs = true,
    time        = { 12, 0 },
    weather     = 'EXTRASUNNY',
}

-- Standard-Einstellungen (jeder Spieler kann sie im Menü unter "Einstellungen" ändern)
Config.Hud = {
    hitmarker       = true,
    hitSound        = true,
    killSound       = true,
    damageNumbers   = true,
    damageDirection = true,
    killfeed        = true,
    killfeedSeconds = 6,
    clock           = true,
    chatFade        = true,      -- alte Chat-Nachrichten ausblenden
    hudScale        = 1.0,       -- 0.8 bis 1.2
    volume          = 0.5,
    hitmarkerStyle  = 'x',       -- x | cross | dot | circle
    hitmarkerColor  = 'white',   -- white | red | blue | yellow | green | pink
    hitSoundType    = 'classic', -- classic | click | ding | pop | bass
    killSoundType   = 'classic', -- classic | ding | headshot | coin | bass | none
    lang            = 'de',      -- 'de' oder 'en' (jeder Spieler stellt das selbst um)
}

Config.KillstreakAnnounce = { 5, 10, 15, 20, 25, 30 }

-- Todesbildschirm: Profilbild des Killers
-- Standard ist ein Foto seines Charakters. Mit einem Discord-Bot-Token in der
-- server.cfg kommt stattdessen sein Discord-Profilbild (wenn Discord verknüpft ist):
--   set bodyshot_discordToken "DEIN_BOT_TOKEN"     (immer "set", nie "setr"!)
Config.DeathScreen = {
    discordAvatars = true,
}


-- -----------------------------------------------------------------------
--  GLÜCKSRAD  (F2 → Glücksrad oder /gluecksrad) – einmal alle 24 Stunden
-- -----------------------------------------------------------------------
-- weight = Chance (muss nicht 100 ergeben). Gewinn: money, xp, case, weapon oder premium.
-- Waffe schon im Besitz -> stattdessen Config.Battlepass.duplicateMoney.
Config.Wheel = {
    enabled       = true,
    cooldownHours = 24,
    prizes = {
        { label = '$1.000',        money = 1000,  weight = 26,  color = '#2f80ff' },
        { label = '500 XP',        xp = 500,      weight = 16,  color = '#34e39a' },
        { label = '$2.500',        money = 2500,  weight = 18,  color = '#19b2ff' },
        { label = 'Street Case',   case = 'street', weight = 8, color = '#2f9bff' },
        { label = '$5.000',        money = 5000,  weight = 11,  color = '#0a8fe0' },
        { label = '1.500 XP',      xp = 1500,     weight = 7,   color = '#1fbf7a' },
        { label = 'Carbine Rifle', weapon = 'WEAPON_CARBINERIFLE', weight = 3, color = '#ff8c1a' },
        { label = '$10.000',       money = 10000, weight = 5,   color = '#8a5cff' },
        { label = 'Mk II Case',    case = 'mk2',  weight = 3,   color = '#b45cff' },
        { label = '$25.000',       money = 25000, weight = 1.5, color = '#ff4fa3' },
        { label = 'Gold Case',     case = 'gold', weight = 0.8, color = '#ffb020' },
        { label = '7 Tage Premium', premium = true, premiumDays = 7, weight = 0.4, color = '#ffd86a' },
    },
}


-- -----------------------------------------------------------------------
--  EMOTES & TÄNZE  (Taste K oder /e <name>, /e stop zum Abbrechen)
-- -----------------------------------------------------------------------
-- Die Liste steht in shared/emotes.lua. Bewegen oder Schießen bricht ab.
Config.Emotes = {
    enabled = true,
    key     = 'K',
    inCombat = false,   -- true = auch im FFA/Gangwar erlaubt (sonst nur an der Hood)
}


-- -----------------------------------------------------------------------
--  LOGS  (Datei + Discord-Webhooks)
-- -----------------------------------------------------------------------
-- Die Webhook-Links stehen in der server.cfg (nie hier, nie mit "setr"):
--   set bodyshot_webhook_logs      "https://discord.com/api/webhooks/..."
--   set bodyshot_webhook_anticheat "https://discord.com/api/webhooks/..."
-- Dateien: <Server-Ordner>/logs/bodyshot-JJJJ-MM-TT.log
-- IP-Adressen werden NIE geloggt.
Config.Logs = {
    file = true,
    -- Was zusätzlich in den Discord-Kanal geht (in die Datei kommt immer alles)
    webhook = {
        join = true, leave = true, register = true, admin = true, ban = true, gangwar = true,
        team = true, shop = true, wheel = true, case = true, kill = false, chat = false, server = true,
    },
}


-- -----------------------------------------------------------------------
--  ANTICHEAT
-- -----------------------------------------------------------------------
-- Aktion pro Erkennung: 'log' = nur melden, 'kick' = rauswerfen, 'ban' = bannen
-- Jede Erkennung geht in den Anticheat-Webhook.
Config.AntiCheat = {
    enabled      = true,
    banHours     = 0,          -- 0 = für immer
    explosion    = 'ban',      -- Explosionen gibt es auf diesem Server nicht
    weapon       = 'kick',     -- Waffe in der Hand, die man nicht besitzt (z. B. RPG, Minigun)
    damageWeapon = 'kick',     -- Schaden mit einer nicht gekauften Waffe
    teleport     = 'log',      -- zu schnell bewegt (Teleport / Speedhack)
    speedOnFoot  = 70.0,       -- m/s zu Fuß (freier Fall schafft ca. 55)
    speedVehicle = 130.0,      -- m/s im Auto
    entity       = 'kick',     -- selbst gespawnte NPCs / verbotene Fahrzeuge
    objectsPer10s = 25,        -- mehr Objekte in 10 s = Spam
    adminEvent   = 'ban',      -- Admin-Aktion ohne Admin-Recht
    heartbeat    = 'kick',     -- Skript beim Spieler gestoppt (Mod-Menü)
    heartbeatSeconds = 90,
    strikesBeforeAction = 3,   -- 'log'-Erkennungen: ab so vielen in 10 min wird gekickt
}

-- Wer Admin-Rechte hat (in der server.cfg vergeben)
Config.AdminAce = 'bodyshot_pvp.admin'


-- =======================================================================
--  NEU IN v5
-- =======================================================================

-- -----------------------------------------------------------------------
--  SPRACHE  (jeder Spieler stellt sie selbst ein: F2 → Einstellungen)
-- -----------------------------------------------------------------------
Config.DefaultLanguage = 'de'        -- 'de' oder 'en'


-- -----------------------------------------------------------------------
--  PREMIUM
-- -----------------------------------------------------------------------
-- Neue Spieler bekommen Premium zum Testen. Vergeben: /premium <User-ID> <Tage>
-- (0 Tage = für immer, -1 = wegnehmen) oder im Admin-Menü (F6).
Config.Premium = {
    trialDays = 7,
}


-- -----------------------------------------------------------------------
--  WESTE & MEDKIT  (Taste G = Weste, H = Medkit – im Inventar kaufen)
-- -----------------------------------------------------------------------
Config.Items = {
    vest   = { label = 'Weste',  key = 'G', seconds = 3.5, armour = 100, price = 250, max = 10 },
    medkit = { label = 'Medkit', key = 'H', seconds = 3.5, health = 100, price = 250, max = 10 },
    unlimited   = true,              -- true = gratis und unbegrenzt (nichts kaufen), false = Anzahl + Kaufen
    startAmount = 5,                 -- nur bei unlimited = false: so viele bekommt jeder neue Account
    allowInDuel = false,
}


-- -----------------------------------------------------------------------
--  WAFFEN-AUFSÄTZE  (nur Premium, F2 → Inventar → Aufsätze)
-- -----------------------------------------------------------------------
-- Pro Platz mehrere Möglichkeiten. Was eine Waffe nicht kann, blendet das
-- Spiel automatisch aus. Aufsätze ändern den Schaden NICHT (Bodyshot bleibt).
Config.Attachments = {
    premiumOnly = true,
    slots = {
        { key = 'clip',   label = 'Magazin',   options = {
            { label = 'Erweitert', suffix = '_CLIP_02' }, { label = 'Trommel', suffix = '_CLIP_03' } } },
        { key = 'scope',  label = 'Visier',    options = {
            { label = 'Holo-Visier', component = 'COMPONENT_AT_SIGHTS' },
            { label = 'Klein',  component = 'COMPONENT_AT_SCOPE_SMALL' }, { label = 'Klein Mk II', component = 'COMPONENT_AT_SCOPE_SMALL_MK2' },
            { label = 'Makro',  component = 'COMPONENT_AT_SCOPE_MACRO' }, { label = 'Makro Mk II', component = 'COMPONENT_AT_SCOPE_MACRO_MK2' },
            { label = 'Makro Mk II (2)', component = 'COMPONENT_AT_SCOPE_MACRO_02_MK2' },
            { label = 'Mittel', component = 'COMPONENT_AT_SCOPE_MEDIUM' }, { label = 'Mittel Mk II', component = 'COMPONENT_AT_SCOPE_MEDIUM_MK2' } } },
        { key = 'muzzle', label = 'Mündung',   options = {
            { label = 'Schalldämpfer', component = 'COMPONENT_AT_AR_SUPP' }, { label = 'Schalldämpfer', component = 'COMPONENT_AT_AR_SUPP_02' },
            { label = 'Flach', component = 'COMPONENT_AT_MUZZLE_01' }, { label = 'Taktisch', component = 'COMPONENT_AT_MUZZLE_02' },
            { label = 'Schwer', component = 'COMPONENT_AT_MUZZLE_04' }, { label = 'Präzise', component = 'COMPONENT_AT_MUZZLE_03' } } },
        { key = 'grip',   label = 'Griff',     options = {
            { label = 'Griff', component = 'COMPONENT_AT_AR_AFGRIP' }, { label = 'Griff Mk II', component = 'COMPONENT_AT_AR_AFGRIP_02' } } },
        { key = 'flash',  label = 'Taschenlampe', options = {
            { label = 'Taschenlampe', component = 'COMPONENT_AT_AR_FLSH' } } },
    },
}


-- -----------------------------------------------------------------------
--  EINLADEN  (Ref-Code = User-ID des Einladers, bei der Registrierung)
-- -----------------------------------------------------------------------
Config.Referral = {
    enabled = true,
    newPlayer = { money = 5000, case = 'street' },      -- sofort für den Neuen
    inviter   = { money = 10000, xp = 1000 },           -- für den Einlader ...
    minutes   = 60,                                     -- ... sobald der Neue so lange gespielt hat
    -- Extra-Belohnungen ab X bestätigten Einladungen
    milestones = {
        { count = 3,  reward = { money = 15000, case = 'mk2' } },
        { count = 5,  reward = { money = 25000, case = 'gold' } },
        { count = 10, reward = { money = 50000, premiumDays = 30 } },
    },
}


-- -----------------------------------------------------------------------
--  KLEIDERSCHRANK an der Hood  (/kleidung oder F2 → Kleiderschrank)
-- -----------------------------------------------------------------------
-- Das Oberteil bleibt IMMER in der Gangfarbe (damit man sieht, wer zu wem
-- gehört). Hose, Schuhe, Kopfbedeckung, Brille und Kette sind frei wählbar.
-- gangColor = true: Hose/Schuhe dürfen auch die Gang-Variante sein (Standard)
Config.Wardrobe = {
    enabled = true,
    slots = {
        { key = 'top',     label = 'Oberteil (Gangfarbe)', gang = true },
        { key = 'legs',    label = 'Hose',         component = 4 },
        { key = 'shoes',   label = 'Schuhe',       component = 6 },
        { key = 'hat',     label = 'Kopfbedeckung', prop = 0 },
        { key = 'glasses', label = 'Brille',       prop = 1 },
        { key = 'chain',   label = 'Kette',        component = 7 },
    },
    maxDrawable = 500,
}


-- -----------------------------------------------------------------------
--  SPIELER AUF DER KARTE  (alle 30 Sekunden, nur Gang-Farbe + Gang-Name)
-- -----------------------------------------------------------------------
Config.PlayerBlips = {
    enabled = true,
    seconds = 30,
    showOwnTeam = true,
}


-- -----------------------------------------------------------------------
--  DISCORD-BOT  (Rollen-Sync + Steuerung über Slash-Befehle)
-- -----------------------------------------------------------------------
-- Der Bot spricht über eine lokale Schnittstelle mit dem Server:
--   set bodyshot_api_token "<langes Geheimwort>"   (in server.cfg, gleich wie im Bot)
-- Discord-Rollen -> Premium im Spiel (Rollen-Namen, endet mit …)
-- Die Team-Ränge über Discord stehen unten bei Config.Staff.discordRoles.
Config.DiscordRoles = {
    premium = { 'Premium', 'Booster' },   -- bekommen im Spiel Premium, solange sie die Rolle haben
    booster = { 'Server Booster', 'Booster' },   -- zeigen im Spiel ihr Discord-Banner (Todesbildschirm, Profil)
}


-- -----------------------------------------------------------------------
--  TEAM-RÄNGE  (Admin-Menü F6)
-- -----------------------------------------------------------------------
-- Reihenfolge = niedrig -> hoch. Jeder Rang darf alles, was die Ränge
-- darunter dürfen. Vergeben wird ein Rang auf drei Wegen:
--   1. server.cfg:  add_principal identifier.license:XYZ group.moderator
--   2. Discord-Rolle (siehe discordRoles, der Bot gleicht das ab)
--   3. Im Admin-Menü (F6 → Spieler → Rang), ab Teamverwaltung
Config.Staff = {
    ranks = {
        { key = 'support',        label = 'Support',        color = '#34e39a' },
        { key = 'moderator',      label = 'Moderator',      color = '#19b2ff' },
        { key = 'gangverwaltung', label = 'Gangverwaltung', color = '#b45cff' },
        { key = 'teamverwaltung', label = 'Teamverwaltung', color = '#ff8c1a' },
        { key = 'admin',          label = 'Admin',          color = '#ff4d61' },
        { key = 'owner',          label = 'Owner',          color = '#ffc24a' },
    },
    -- Ab welchem Rang eine Aktion erlaubt ist
    -- Geben (Geld, XP, Premium, Cases) dürfen NUR Admin und Owner.
    actions = {
        heal = 'support', hood = 'support', mute = 'support', kick = 'support',
        tpTo = 'support', bring = 'support', endDuel = 'support',
        ban = 'moderator', unban = 'moderator', unbanId = 'moderator', troll = 'moderator',
        zone = 'gangverwaltung', endwar = 'gangverwaltung', disband = 'gangverwaltung', clearArena = 'gangverwaltung', sethood = 'gangverwaltung',
        announce = 'teamverwaltung', healAll = 'teamverwaltung', setRank = 'teamverwaltung',
        money = 'admin', xp = 'admin', premium = 'admin', case = 'admin', clearBounty = 'admin',
    },
    -- Discord-Rolle (Name endet mit …) -> Rang im Spiel
    discordRoles = {
        support        = { 'Support', 'Supporter' },
        moderator      = { 'Moderator' },
        gangverwaltung = { 'Gangverwaltung' },
        teamverwaltung = { 'Teamverwaltung' },
        admin          = { 'Admin' },
        owner          = { 'Owner' },
    },
    showInChat = true,     -- Rang vor dem Namen im Chat
}

-- -----------------------------------------------------------------------
--  DISCORD RICH PRESENCE  ("Spielt Bodyshot Gangwar" im Discord-Profil)
-- -----------------------------------------------------------------------
-- appId = Application-ID aus dem Discord Developer Portal (hier: euer Bot)
-- Bilder: Developer Portal -> App -> Rich Presence -> Art Assets hochladen,
-- der Name dort muss zu largeImage / smallImage passen.
Config.DiscordRPC = {
    enabled    = true,
    appId      = '1563081805035339857',
    largeImage = 'logo',
    largeText  = 'Bodyshot Gangwar',
    seconds    = 15,                     -- so oft wird der Text aktualisiert
    buttons    = {
        { label = 'Discord beitreten', url = 'https://discord.gg/p24Wzcqqpp' },
    },
}