'use strict';
// =======================================================================
//  Sprache: Deutsch (Grundsprache) oder Englisch
//  Alles, was auf dem Bildschirm erscheint, läuft automatisch durch dieses
//  Wörterbuch (feste Texte + Muster für Texte mit Zahlen/Namen).
//  Fehlt ein Text, bleibt er einfach deutsch – neue Einträge unten ergänzen.
// =======================================================================

const I18N_EXACT = {
    // Navigation & Seiten
    'Kämpfen': 'Fight', 'Belohnungen': 'Rewards', 'Server': 'Server', 'Du': 'You',
    'Free for all': 'Free for all', 'Gangwar': 'Gang war', '1v1-Duelle': '1v1 duels', '1v1-Duell': '1v1 duel',
    'Täglich': 'Daily', 'Glücksrad': 'Lucky wheel', 'Cases & Skins': 'Cases & skins', 'Battlepass': 'Battle pass',
    'Waffenshop': 'Weapon shop', 'Kopfgeld': 'Bounty', 'Rangliste': 'Leaderboard', 'Spieler': 'Players',
    'Regelwerk': 'Rules', 'Inventar': 'Inventory', 'Emotes & Tänze': 'Emotes & dances', 'Team': 'Team',
    'Profil': 'Profile', 'Einstellungen': 'Settings', 'Discord': 'Discord', 'Einladen': 'Invite friends',
    'Kleiderschrank': 'Wardrobe',
    'Jeder gegen jeden. Wähl eine Arena.': 'Everyone against everyone. Pick an arena.',
    'Greif Gebiete an und verteidige, was deinem Team gehört.': 'Attack zones and defend what belongs to your team.',
    'Die zehn Spieler mit den meisten Kills.': 'The ten players with the most kills.',
    'Wer sich nicht daran hält, fliegt.': 'Break them and you are out.',
    'Wer gerade online ist.': 'Who is online right now.',
    'Dein Team und dein privates Team.': 'Your team and your private team.',
    'Einmal kaufen, für immer im Loadout.': 'Buy once, keep forever.',
    'XP gibt es für Kills und Gangwars.': 'You get XP for kills and gang wars.',
    'Gilt nur für dich und bleibt gespeichert.': 'Only for you, saved automatically.',
    'Deine Werte auf diesem Server.': 'Your stats on this server.',
    'Jeden Tag drei Missionen und ein Bonus fürs Einloggen.': 'Three missions every day plus a login bonus.',
    'Echte GTA-Lackierungen für deine Waffen. Einmal gezogen, für immer deins.': 'Real GTA finishes for your weapons. Unbox once, keep forever.',
    'Fordere jemanden heraus. Best of 3, eigene Arena, gleiche Waffe.': 'Challenge someone. Best of 3, private arena, same weapon.',
    'Setz Geld auf einen Kopf. Wer ihn im FFA oder Gangwar erwischt, kassiert.': 'Put money on a head. Whoever gets them in FFA or a gang war cashes in.',
    'Alles, was dir gehört. Deine Waffen hast du immer dabei.': 'Everything you own. Your weapons are always with you.',
    'Einmal am Tag drehen – Geld, XP, Cases, Waffen oder Premium.': 'Spin once a day – money, XP, cases, weapons or premium.',
    'Klick drauf oder schreib /e <name>. Bewegen bricht ab. Taste K öffnet diese Seite.': 'Click or type /e <name>. Moving cancels. Key K opens this page.',
    'Lade Freunde ein: Sie geben bei der Registrierung deine User-ID ein.': 'Invite friends: they enter your user ID when they register.',

    // HUD
    'Kills': 'Kills', 'Tode': 'Deaths', 'K/D': 'K/D', 'Online': 'Online', 'Kopfgeld auf dich': 'Bounty on you',
    'Spielzeit-Bonus': 'Playtime bonus', 'Eliminiert': 'Eliminated', 'Zurück in die Zone': 'Back into the zone',
    'Spawnschutz': 'Spawn protection', 'Garage': 'Garage', 'Gangwar-Garage': 'Gang war garage', 'Level up': 'Level up',
    'Respawn': 'Respawn', 'Herausforderung zum 1v1': '1v1 challenge', 'Annehmen': 'Accept', 'Ablehnen': 'Decline',
    'Willkommen bei': 'Welcome to', 'Safezone': 'Safe zone', 'Kampfzone': 'Combat zone', 'Hood': 'Hood',
    'Vorbereitung': 'Preparation', 'Kampf': 'Fight', 'Ende': 'End', 'Runde 1': 'Round 1', 'Gegner': 'Opponent',
    'Ziehe Weste': 'Putting on vest', 'Benutze Medkit': 'Using medkit', 'Weste': 'Vest', 'Medkit': 'Medkit',
    'Alle': 'All', 'Alle/Team': 'All/Team', '(Team)': '(Team)', 'Nachricht oder /befehl': 'Message or /command',
    'senden': 'send', 'schließen': 'close',

    // Tod
    'von': 'by', 'Gestorben': 'Died', 'Neustart': 'Restart', 'Runde verloren': 'Round lost',
    'Du hast /kill benutzt.': 'You used /kill.', 'Du bist abgestürzt.': 'You fell to your death.',
    'Kein Gegner beteiligt.': 'No enemy involved.', 'Leben übrig': 'Health left', 'Weste übrig': 'Armour left',
    'Ohne Team': 'No team', 'Serie': 'Streak', 'Beste Serie': 'Best streak', 'Level': 'Level',
    'gleich geht die nächste Runde los': 'next round starts soon',

    // Login & Teams
    'Account erstellen': 'Create account', 'Betreten': 'Enter', 'Neu hier? Wähl deinen Namen': 'New here? Pick your name',
    'Spielername': 'Player name', 'Modus-Auswahl': 'Mode select', 'Einladungs-Code (optional)': 'Invite code (optional)',
    'User-ID von dem, der dich eingeladen hat': 'User ID of whoever invited you',
    'Das hat nicht geklappt. Versuch es noch einmal.': 'That did not work. Try again.',
    'Keine Rockstar-Lizenz gefunden. Starte FiveM neu und verbinde dich noch einmal.': 'No Rockstar license found. Restart FiveM and connect again.',
    'Nur Langwaffen, 14 bis 17 Treffer bis zum Kill, Gangs und Gebiete': 'Rifles only, 14 to 17 hits to kill, gangs and zones',
    'Teams': 'Teams', 'Team suchen': 'Search team', 'Öffentlich': 'Public', 'Privat': 'Private', 'Dein Team': 'Your team',
    'Privates Team': 'Private team', 'Nur Mitglieder': 'Members only', 'Voll': 'Full', 'Bleiben': 'Stay',
    'Eigenes Team': 'Own team', 'Eigenes Team gründen': 'Found your own team', 'Kein Team gefunden.': 'No team found.',
    'Noch keine privaten Teams.': 'No private teams yet.', 'Teamname': 'Team name', 'Teamname, z. B. Grove Kings': 'Team name, e.g. Grove Kings',
    'Kürzel, z. B. GK': 'Tag, e.g. GK', 'Kürzel (2 bis 4 Zeichen)': 'Tag (2 to 4 characters)',
    'Farbe (bestimmt auch die Outfits)': 'Colour (also sets the outfits)', 'Gründen geht nur an der Hood': 'Only at your hood',
    'Team wechseln': 'Change team', 'Team verlassen': 'Leave team', 'Team auflösen': 'Disband team',
    'Wirklich verlassen?': 'Really leave?', 'Wirklich auflösen?': 'Really disband?', 'Einladung von': 'Invite from',
    'Entfernen': 'Remove', 'Private Teams': 'Private teams', 'Private Teams sind auf diesem Server ausgeschaltet.': 'Private teams are disabled on this server.',
    'Wechseln kannst du jederzeit an deiner Hood.': 'You can switch any time at your hood.', 'Wechseln geht nur an deiner Hood.': 'Switching only works at your hood.',
    'Du spielst für': 'You play for', 'Kein Team': 'No team', 'User-ID einladen, z. B. 12': 'Invite user ID, e.g. 12',

    // FFA / Gangwar
    'Zurück zur Hood': 'Back to hood', 'Gerade leer': 'Empty right now', 'Du bist hier': 'You are here',
    'Aus dem Gangwar geht es erst zurück zur Hood.': 'From a gang war you go back to your hood first.',
    'Kills geben Geld und XP. Jeder Kill heilt dich voll.': 'Kills give money and XP. Every kill heals you fully.',
    'Angreifen': 'Attack', 'Beitreten': 'Join', 'Verteidigen': 'Defend', 'Du kämpfst hier': 'You fight here',
    'Andere Teams kämpfen hier.': 'Other teams are fighting here.', 'Gehört euch': 'Yours', 'Frei': 'Free',
    'Keine Gebiete eingestellt.': 'No zones configured.', 'Hoods': 'Hoods', 'Gangwar läuft': 'Gang war running',

    // Rangliste / Spieler / Profil
    'Platz': 'Rank', 'Gangwar-Siege': 'Gang war wins', 'Deine Werte': 'Your stats', 'Gangwars gewonnen': 'Gang wars won',
    'Noch keine Kills auf dem Server. Platz 1 ist frei.': 'No kills on the server yet. Rank 1 is free.',
    'Ort': 'Place', 'Ping': 'Ping', 'Zum Duell fordern': 'Challenge to a duel', 'Kopfgeld setzen': 'Place bounty',
    'Kein Regelwerk eingetragen.': 'No rules set.', 'Geld': 'Money', 'Spielzeit': 'Playtime', 'Dabei seit': 'Member since',
    'Waffen': 'Weapons', 'Duelle': 'Duels', 'Kopfgelder': 'Bounties', 'Kopfgeld kassiert': 'Bounty earned',
    'Cases geöffnet': 'Cases opened', 'Skins': 'Skins', 'Gangwars': 'Gang wars', 'Premium': 'Premium',
    'Premium aktiv': 'Premium active', 'Kein Premium': 'No premium', 'für immer': 'forever', 'Für immer': 'Forever',
    'über Discord-Rolle': 'via Discord role', 'aus': 'off',

    // Shop / Battlepass / Inventar
    'Kaufen': 'Buy', 'Gehört dir': 'Yours', 'Im Besitz': 'Owned', 'Startwaffe': 'Starter weapon', 'Treffer bis Kill': 'Hits to kill',
    'Schaden': 'Damage', 'Weniger Treffer bis zum Kill heißt mehr Schaden. Mk-II-Waffen sind am stärksten.': 'Fewer hits to kill means more damage. Mk II weapons are the strongest.',
    'Gratis': 'Free', 'Abholen': 'Claim', 'Abgeholt': 'Claimed', 'Nur mit Premium': 'Premium only', 'Nichts': 'Nothing',
    'Maximales Level erreicht.': 'Max level reached.', 'In die Hand': 'Equip', 'Skin': 'Skin', 'Standard': 'Default',
    'Noch keine Waffen.': 'No weapons yet.', 'Cases': 'Cases', 'Keine ungeöffneten Cases.': 'No unopened cases.',
    'Öffnen': 'Open', 'Autos frei': 'Cars unlocked', 'Autos in deiner Hood-Garage': 'Cars in your hood garage', 'Ja': 'Yes', 'Nein': 'No',
    'Klick auf eine Waffe, um sie direkt in die Hand zu nehmen.': 'Click a weapon to equip it right away.',
    'Deine Waffen bekommst du, sobald du wieder kämpfst.': 'You get your weapons as soon as you fight again.',
    'Aufsätze': 'Attachments', 'Aufsätze (Premium)': 'Attachments (premium)', 'Aufsätze gibt es nur mit Premium.': 'Attachments are premium only.',
    'Keine': 'None', 'Magazin': 'Magazine', 'Visier': 'Scope', 'Mündung': 'Muzzle', 'Griff': 'Grip', 'Taschenlampe': 'Flashlight',
    'Erweitert': 'Extended', 'Trommel': 'Drum', 'Schalldämpfer': 'Suppressor', 'Klein': 'Small', 'Mittel': 'Medium', 'Makro': 'Macro',
    'Holo-Visier': 'Holo sight', 'Flach': 'Flat', 'Taktisch': 'Tactical', 'Schwer': 'Heavy', 'Präzise': 'Precision',
    'Diese Waffe hat keine Aufsätze.': 'This weapon has no attachments.', 'Fertig': 'Done',
    'Weste & Medkit': 'Vest & medkit', 'Kaufen ×1': 'Buy ×1', 'Kaufen ×5': 'Buy ×5',

    // Glücksrad / Emotes / Einladen
    'Tägliches Glücksrad': 'Daily lucky wheel', 'Drehen!': 'Spin!', 'Dreht …': 'Spinning …', 'Ausgeschaltet': 'Disabled',
    'Einmal alle 24 Stunden gratis. Der Gewinn wird sofort gutgeschrieben.': 'Free once every 24 hours. Prizes are credited instantly.',
    'Emote stoppen': 'Stop emote', 'Tänze': 'Dances', 'Gesten': 'Gestures', 'Emotes gehen nur an deiner Hood.': 'Emotes only work at your hood.',
    'Klick spielt das Emote ab. Laufen, springen oder zielen bricht ab.': 'Click to play. Walking, jumping or aiming cancels.',
    'Dein Einladungs-Code': 'Your invite code', 'Eingeladen': 'Invited', 'Wartet noch': 'Pending', 'Verdient': 'Earned',
    'Meilensteine': 'Milestones', 'Erreicht': 'Reached', 'Code kopieren': 'Copy code', 'Kopiert!': 'Copied!',

    // Einstellungen
    'Trefferanzeige': 'Hit marker', 'Kreuz in der Mitte bei jedem Treffer': 'Cross in the centre on every hit',
    'Treffer-Sound': 'Hit sound', 'Kurzer Ton bei jedem Treffer': 'Short sound on every hit', 'Kill-Sound': 'Kill sound',
    'Ton bei jedem Kill': 'Sound on every kill', 'Schadenszahlen': 'Damage numbers', 'Zeigt den Schaden pro Treffer': 'Shows damage per hit',
    'Trefferrichtung': 'Hit direction', 'Zeigt, aus welcher Richtung du getroffen wirst': 'Shows where you are hit from',
    'Killfeed': 'Kill feed', 'Wer wen erwischt hat, oben rechts': 'Who killed whom, top right', 'Uhr': 'Clock',
    'Datum und Uhrzeit oben links': 'Date and time top left', 'Chat ausblenden': 'Fade chat',
    'Alte Nachrichten verschwinden nach ein paar Sekunden': 'Old messages fade after a few seconds',
    'Lautstärke': 'Volume', 'Treffer- und Kill-Sounds': 'Hit and kill sounds', 'HUD-Größe': 'HUD size', 'Statistik, Chat und Munition': 'Stats, chat and ammo',
    'Sprache': 'Language', 'Deutsch oder Englisch': 'German or English', 'Stil der Trefferanzeige': 'Hit marker style',
    'Farbe der Trefferanzeige': 'Hit marker colour', 'Welcher Ton beim Treffer': 'Which sound on hit', 'Welcher Ton beim Kill': 'Which sound on kill',
    'Kreuz': 'Cross', 'Punkt': 'Dot', 'Kreis': 'Circle', 'Weiß': 'White', 'Rot': 'Red', 'Blau': 'Blue', 'Gelb': 'Yellow', 'Grün': 'Green', 'Pink': 'Pink',
    'Klassisch': 'Classic', 'Klick': 'Click', 'Ding': 'Ding', 'Pop': 'Pop', 'Bass': 'Bass', 'Münze': 'Coin', 'Headshot': 'Headshot', 'Aus': 'Off',
    'Anhören': 'Preview',

    // Garage / Kleiderschrank
    'Ausparken': 'Take out', 'In der Garage stehen keine Autos.': 'No cars in the garage.', 'Dein Level': 'Your level',
    'Speichern': 'Save', 'Abbrechen': 'Cancel', 'Drehen': 'Rotate', 'Oberteil (Gangfarbe)': 'Top (gang colour)', 'Hose': 'Pants',
    'Schuhe': 'Shoes', 'Kopfbedeckung': 'Headwear', 'Brille': 'Glasses', 'Kette': 'Chain',
    'Das Oberteil bleibt in deiner Gangfarbe, damit jeder sieht, zu wem du gehörst.': 'Your top stays in your gang colour so everyone sees who you belong to.',
    'Kleiderschrank öffnen': 'Open wardrobe',

    // Admin
    'Admin': 'Admin', 'Gebiete': 'Zones', 'Banns': 'Bans', 'Heilen': 'Heal', 'Zur Hood': 'To hood', 'Premium geben': 'Give premium',
    'Premium weg': 'Remove premium', 'Stumm 30 min': 'Mute 30 min', 'Stumm aufheben': 'Unmute', 'Geld und XP': 'Money and XP',
    'Strafen': 'Punishments', 'Grund': 'Reason', 'Stunden (0 = für immer)': 'Hours (0 = forever)', 'Kicken': 'Kick', 'Bannen': 'Ban',
    'Wirklich kicken?': 'Really kick?', 'Wirklich bannen?': 'Really ban?', 'Extras': 'Extras', 'Kopfgeld löschen': 'Clear bounty',
    'Duell beenden': 'End duel', 'Teleport': 'Teleport', 'Zu ihm': 'Go to', 'Zu mir holen': 'Bring', 'Troll': 'Troll',
    'Spieler links anklicken, um ihn zu verwalten.': 'Click a player on the left to manage them.', 'Niemand online.': 'Nobody online.',
    'Setzen': 'Set', 'Beenden': 'End', 'Sicher?': 'Sure?', 'Speicher': 'Storage', 'Ankündigung': 'Announcement',
    'Text für alle Spieler (Banner + Chat)': 'Text for all players (banner + chat)', 'Senden': 'Send', 'Schnell': 'Quick',
    'Alle heilen': 'Heal all', 'Alle FFA-Arenen leeren': 'Clear all FFA arenas', 'Wirklich alle?': 'Really all?', 'FFA-Arenen': 'FFA arenas',
    'Leeren': 'Clear', 'Keine privaten Teams.': 'No private teams.', 'Auflösen': 'Disband', 'Von': 'By', 'Dauer': 'Duration',
    'Aufheben': 'Lift', 'Niemand ist gebannt.': 'Nobody is banned.', 'Frei (niemand)': 'Free (nobody)', 'Neu laden': 'Reload', 'Stumm': 'Muted',
    'Premium-Tage': 'Premium days',

    // häufige Meldungen vom Server
    'Wähle zuerst ein Team.': 'Pick a team first.', 'Teams wechselst du an deiner Hood.': 'You change teams at your hood.',
    'Du hast keine Admin-Rechte.': 'You have no admin rights.', 'Umziehen geht nur an deiner Hood.': 'You can only change clothes at your hood.',
    'Outfit gespeichert.': 'Outfit saved.', 'Deine Weste ist schon voll.': 'Your armour is already full.', 'Du hast schon volles Leben.': 'You already have full health.',
    'Abgebrochen – du wurdest getroffen.': 'Cancelled – you were hit.', 'Fahrzeug repariert.': 'Vehicle repaired.',
    'Setz dich zuerst in ein Fahrzeug.': 'Get into a vehicle first.', 'Reparieren geht nicht im FFA oder Gangwar.': 'Repairing does not work in FFA or gang wars.',
    'Geh näher an die Garage.': 'Move closer to the garage.', 'Du bist schon an deiner Hood.': 'You are already at your hood.',
    'Steig zuerst aus dem Fahrzeug aus.': 'Get out of the vehicle first.', 'Gerade nicht möglich.': 'Not possible right now.',
    'Das Glücksrad ist bereit – F2 → Glücksrad oder /gluecksrad': 'The lucky wheel is ready – F2 → Lucky wheel or /wheel',
    'Premium ist jetzt aktiv!': 'Premium is now active!', 'Dein Premium ist abgelaufen.': 'Your premium has expired.',
    'Nicht so schnell – warte kurz.': 'Not so fast – wait a moment.', 'Dieses Team ist gerade voll.': 'This team is full right now.',
    'Die zehn Spieler': 'The ten players',

    // Team-Ränge, Hilfe (F11), Discord-Profil
    'Support': 'Support', 'Moderator': 'Moderator', 'Gangverwaltung': 'Gang management', 'Teamverwaltung': 'Staff management',
    'Owner': 'Owner', 'Aktionen': 'Actions', 'Geben (nur Admin)': 'Give (admin only)', 'Team-Rang': 'Staff rank', 'Kein Rang': 'No rank',
    'Rang kommt aus der server.cfg oder einer Discord-Rolle.': 'Rank comes from server.cfg or a Discord role.',
    'Gegen ein gleich- oder höherrangiges Teammitglied geht das nicht.': 'Not possible against an equal or higher staff member.',
    'Gratis · unbegrenzt': 'Free · unlimited', 'Volle Weste in 3,5 s': 'Full armour in 3.5 s', 'Volles Leben in 3,5 s': 'Full health in 3.5 s',
    'Befehle & Tasten': 'Commands & keys', 'Befehl suchen': 'Search command', 'Tasten': 'Keys', 'Befehle': 'Commands', 'Nichts gefunden.': 'Nothing found.',
    'Teams wählen und wechseln (an der Hood)': 'Pick and switch teams (at your hood)',
    'Hauptmenü: FFA, Gangwar, Inventar, Shop, Battlepass …': 'Main menu: FFA, gang war, inventory, shop, battle pass …',
    'Fahrzeug reparieren (an der Hood)': 'Repair vehicle (at your hood)', 'Garage an der Hood und am Gangwar-Spawn': 'Garage at your hood and gang war spawn',
    'Weste ziehen (3,5 s)': 'Put on vest (3.5 s)', 'Medkit benutzen (3,5 s)': 'Use medkit (3.5 s)', 'Chat (Tab = Alle/Team)': 'Chat (Tab = all/team)',
    'Duell annehmen': 'Accept duel', 'Duell ablehnen': 'Decline duel', 'Diese Hilfe': 'This help', 'Zurück zu deiner Hood': 'Back to your hood',
    'FFA, Gangwar oder Duell verlassen': 'Leave FFA, gang war or duel', 'Nur das FFA verlassen': 'Leave FFA only', 'Nur den Gangwar verlassen': 'Leave gang war only',
    'Einer FFA-Arena beitreten': 'Join an FFA arena', 'Gangwar-Seite öffnen': 'Open gang war page', 'Neu spawnen (zählt als Tod)': 'Respawn (counts as a death)',
    'Nachricht an dein Team': 'Message your team', 'Deine User-ID (= dein Einladungs-Code)': 'Your user ID (= your invite code)',
    'Statistik von dir oder einem anderen': 'Stats of you or someone else', 'Top 10 nach Kills': 'Top 10 by kills', '1v1-Duell fordern': 'Challenge to 1v1',
    'Kopfgeld setzen': 'Place bounty', 'Inventar öffnen': 'Open inventory', 'Kleiderschrank (an der Hood)': 'Wardrobe (at your hood)',
    'Tägliches Glücksrad': 'Daily lucky wheel', 'Freunde einladen': 'Invite friends', 'Emote abspielen, /e stop beendet': 'Play emote, /e stop ends it',
    'Weste ziehen': 'Put on vest', 'Medkit benutzen': 'Use medkit', 'Admin-Menü': 'Admin menu', 'Stummschalten (0 = aufheben)': 'Mute (0 = unmute)',
    'Bannen (0 = für immer)': 'Ban (0 = forever)', 'Bann aufheben': 'Unban', 'Gebietsbesitzer setzen': 'Set zone owner', 'Gangwar beenden': 'End gang war',
    'Hood-Punkte setzen': 'Set hood points', 'Ankündigung an alle': 'Announcement to everyone', 'Team-Rang vergeben': 'Assign staff rank',
    'Geld geben': 'Give money', 'XP geben': 'Give XP', 'Case geben': 'Give case', 'Premium (0 = für immer, -1 = weg)': 'Premium (0 = forever, -1 = remove)',
    'Discord nicht verknüpft – Discord beim Start von FiveM offen haben': 'Discord not linked – keep Discord open when starting FiveM',
};

// Muster: [RegExp, Ersatz] – $1, $2 … sind die eingefangenen Teile
const I18N_PATTERNS = [
    [/^Dir fehlen (\$[\d.]+)\.?$/, 'You need $1 more'],
    [/^Gründen für (\$[\d.]+)$/, 'Found for $1'],
    [/^Kostet (\$[\d.]+)\. Bis zu (\d+) Mitglieder, eigene Hood und Farbe\.$/, 'Costs $1. Up to $2 members, own hood and colour.'],
    [/^Noch ([\d.]+) XP bis Level (\d+)$/, '$1 XP to level $2'],
    [/^Waffen \((\d+) von (\d+)\)$/, 'Weapons ($1 of $2)'],
    [/^(\d+) von (\d+)$/, '$1 of $2'],
    [/^Ab Level (\d+)$/, 'From level $1'],
    [/^Nächster Dreh in (.+)$/, 'Next spin in $1'],
    [/^Letzter Gewinn: (.+)$/, 'Last prize: $1'],
    [/^Vorbereitung (.+)$/, 'Preparation $1'], [/^Kampf (\d.+)$/, 'Fight $1'], [/^Ende (\d.+)$/, 'End $1'], [/^Gesperrt (.+)$/, 'Locked $1'],
    [/^(\d+) Spieler drin$/, '$1 players inside'], [/^(\d+) Spieler online$/, '$1 players online'],
    [/^(\d+) gegen (\d+)$/, '$1 vs $2'], [/^mit (.+)$/, 'with $1'], [/^(\d+) Std (\d+) Min$/, '$1 h $2 min'],
    [/^(\d+) Gebiete?$/, '$1 zones'], [/^Du bist in (.+)\. Wechseln geht direkt\.$/, 'You are in $1. You can switch directly.'],
    [/^Runde (\d+)$/, 'Round $1'], [/^noch (\d+) Tage$/, '$1 days left'], [/^noch (\d+) Std$/, '$1 h left'], [/^noch (\d+) min$/, '$1 min left'],
    [/^Modell (\d+) \/ (\d+)$/, 'Model $1 / $2'], [/^Farbe (\d+) \/ (\d+)$/, 'Colour $1 / $2'], [/^Variante (\d+) \/ (\d+)$/, 'Variant $1 / $2'],
    [/^Hol (\d+) Kills$/, 'Get $1 kills'], [/^Hol (\d+) Kills im FFA$/, 'Get $1 kills in FFA'], [/^Hol (\d+) Kills im Gangwar$/, 'Get $1 kills in gang wars'],
    [/^Kämpf in (\d+) Gangwar mit$/, 'Fight in $1 gang war'], [/^Gewinn (\d+) Gangwar$/, 'Win $1 gang war'], [/^Triff (\d+) Mal$/, 'Hit $1 times'],
    [/^Spiel (\d+) Minuten$/, 'Play $1 minutes'], [/^Öffne (\d+) Case$/, 'Open $1 case'], [/^Spiel (\d+) 1v1-Duelle$/, 'Play $1 1v1 duels'],
    [/^Gewinn (\d+) 1v1-Duell$/, 'Win $1 1v1 duel'], [/^Kassier (\d+) Kopfgeld$/, 'Claim $1 bounty'], [/^Schaff eine (\d+)er-Killserie$/, 'Get a $1 kill streak'],
    // Meldungen
    [/^(.+) gekauft – gehört dir jetzt für immer\.$/, '$1 bought – yours forever.'],
    [/^(\d+)x (.+) gekauft \(-(\$[\d.]+)\)\.$/, 'Bought $1x $2 (-$3).'],
    [/^Du hast keine (.+) mehr – kaufen unter F2 → Inventar\.$/, 'You have no $1 left – buy in F2 → Inventory.'],
    [/^(.+) abgebrochen – du wurdest getroffen\.$/, '$1 cancelled – you were hit.'],
    [/^Glücksrad: (.+)$/, 'Lucky wheel: $1'], [/^Spielzeit-Bonus: \+(\$[\d.]+)$/, 'Playtime bonus: +$1'],
    [/^Gebietseinkommen: \+(\$[\d.]+) \((\d+) Gebiete?\)$/, 'Zone income: +$1 ($2 zones)'],
    [/^(.+) greift (.+) an!$/, '$1 attacks $2!'], [/^(.+) erobert (.+) von (.+)!$/, '$1 captures $2 from $3!'],
    [/^(.+) erobert (.+)!$/, '$1 captures $2!'], [/^(.+) verteidigt (.+)!$/, '$1 defends $2!'], [/^Kampf um (.+)!$/, 'Fight for $1!'],
    [/^(.+) besetzt das freie Gebiet (.+)$/, '$1 takes the free zone $2'],
    [/^(.+) hat (\d+) Kills in Folge!$/, '$1 has $2 kills in a row!'], [/^(.+) beendet die (\d+)er-Serie von (.+)$/, '$1 ends the $2 streak of $3'],
    [/^Battlepass Level (\d+) erreicht! Belohnung im Menü abholen\.$/, 'Battle pass level $1 reached! Claim your reward in the menu.'],
    [/^Level (\d+): (.+)$/, 'Level $1: $2'], [/^Du hast jetzt Premium \((.+)\)!$/, 'You now have premium ($1)!'],
    [/^(.+): Park dir am Spawn mit (\w+) ein Auto aus und fahr in die Bubble\. Nur dort wird gekämpft\.$/, '$1: Take a car at your spawn with $2 and drive into the bubble. Fighting only happens there.'],
    [/^Euer Team greift (.+) an! Drück F2 und tritt unter Gangwar bei\.$/, 'Your team is attacking $1! Press F2 and join under Gang war.'],
    [/^Euer Gebiet (.+) wird angegriffen! Drück F2 und verteidige es unter Gangwar\.$/, 'Your zone $1 is under attack! Press F2 and defend it under Gang war.'],
    [/^FFA: (.+)$/, 'FFA: $1'], [/^(.+) ist voll \((\d+)\/(\d+)\)\.$/, '$1 is full ($2/$3).'],
    [/^Warte noch (\d+) Sekunden\.$/, 'Wait $1 more seconds.'], [/^Nächster Dreh in (\d+):(\d+) Std\.$/, 'Next spin in $1:$2 h.'],
    [/^(.+) ausgeparkt\.$/, '$1 taken out.'], [/^(.+) gibt es ab Level (\d+)\.$/, '$1 unlocks at level $2.'],
    [/^Reparieren geht wieder in (\d+) Sekunden\.$/, 'Repair available again in $1 seconds.'],
    [/^(.+) – Du bist zurück an deiner Hood\.$/, '$1 – you are back at your hood.'],
    [/^FFA verlassen\. Du bist zurück an deiner Hood\.$/, 'Left FFA. You are back at your hood.'],
    [/^Gangwar verlassen\. Du bist zurück an deiner Hood\.$/, 'Left the gang war. You are back at your hood.'],
    [/^Eingeladen von (.+) – Willkommensgeschenk: (.+)$/, 'Invited by $1 – welcome gift: $2'],
    [/^Einladung bestätigt \((.+)\): (.+)$/, 'Invite confirmed ($1): $2'],
    [/^Gangwar gewonnen: (.+)$/, 'Gang war won: $1'], [/^Gangwar verloren: (.+)$/, 'Gang war lost: $1'],
    [/^Tagesbonus bereit \(Tag (\d+) der Serie\) – F2 → Täglich$/, 'Daily bonus ready (day $1 of your streak) – F2 → Daily'],
    [/^Willkommen auf (.+)$/, 'Welcome to $1'],
    [/^Dafür reicht dein Rang nicht \(ab (.+)\)\.$/, 'Your rank is not high enough (needs $1).'],
    [/^Du bist jetzt (.+)\.$/, 'You are now $1.'],
    [/^Premium-Tage \(jetzt: (.+)\) – 0 = für immer, -1 = weg$/, 'Premium days (now: $1) – 0 = forever, -1 = remove'],
];

window.I18N = { lang: 'de' };
const I18N_ORIG = new WeakMap();   // Textknoten -> deutscher Originaltext

function T(s) {
    if (window.I18N.lang !== 'en' || s === null || s === undefined) return s;
    const str = String(s);
    const key = str.trim();
    if (!key || !/[A-Za-zÄÖÜäöüß]{2}/.test(key)) return str;
    if (Object.prototype.hasOwnProperty.call(I18N_EXACT, key)) return str.replace(key, I18N_EXACT[key]);
    for (const [re, rep] of I18N_PATTERNS) {
        if (re.test(key)) return str.replace(key, key.replace(re, rep));
    }
    return str;
}

function i18nNode(node) {
    if (node.nodeType === 3) {
        const cur = node.data;
        if (window.I18N.lang === 'en') {
            const tr = T(cur);
            if (tr !== cur) { I18N_ORIG.set(node, cur); node.data = tr; }
        } else if (I18N_ORIG.has(node)) {
            node.data = I18N_ORIG.get(node);
            I18N_ORIG.delete(node);
        }
        return;
    }
    if (node.nodeType !== 1) return;
    if (node.tagName === 'SCRIPT' || node.tagName === 'STYLE') return;
    ['placeholder', 'title'].forEach((attr) => {
        const v = node.getAttribute && node.getAttribute(attr);
        if (!v) return;
        const orig = node.dataset['i18n' + attr] || v;
        if (window.I18N.lang === 'en') {
            const tr = T(orig);
            if (tr !== v) { node.dataset['i18n' + attr] = orig; node.setAttribute(attr, tr); }
        } else if (node.dataset['i18n' + attr]) {
            node.setAttribute(attr, node.dataset['i18n' + attr]);
            delete node.dataset['i18n' + attr];
        }
    });
    node.childNodes.forEach(i18nNode);
}

// Neue/geänderte Texte automatisch übersetzen
const i18nObserver = new MutationObserver((list) => {
    if (window.I18N.lang !== 'en') return;
    list.forEach((m) => {
        if (m.type === 'characterData') i18nNode(m.target);
        else m.addedNodes.forEach(i18nNode);
    });
});

function setLanguage(lang) {
    window.I18N.lang = lang === 'en' ? 'en' : 'de';
    document.documentElement.lang = window.I18N.lang;
    i18nNode(document.body);
}

document.addEventListener('DOMContentLoaded', () => {
    i18nObserver.observe(document.body, { childList: true, subtree: true, characterData: true });
});
