# Bodyshot Gangwar – FiveM Server (v3)

Gangwar-Server mit Bodyshot-System. Kein Framework und keine Datenbank nötig: eine Ressource (`bodyshot_pvp`) reinkopieren, fertig.

## Was drin ist

- **Verbinden:** Beim Joinen erscheint eine Karte mit der **Aufnahmepflicht** (Deutsch und Englisch), einem **Discord-Button** und einem Countdown. Gebannte Spieler kommen hier gar nicht erst rein.
- **Ladebildschirm:**
  - Logo mit Schriftzug-Untertitel, Willkommenstext, Discord- und Shop-Button, wechselnde Tipps
  - **Musikplayer** und **Ladebalken** mit Prozent
  - Im Hintergrund fliegt eine animierte Karte von Los Santos mit den Gebieten in Gang-Farben, darüber schweben blaue Lichter.
- **Modus-Auswahl (Login):** Spielerkarte mit Name, ID, Level-Medaille und XP-Balken, darunter der Modus mit Online-Zahl und **Betreten**. Login ohne Passwort, weil der Account an deinem Rockstar-Account hängt. Jeder Account bekommt eine **User-ID ab 0**.
- **Teams (F1):** Raster mit allen Teams, **Suche** und **Öffentlich/Privat**.
  - Jede Karte zeigt Spieler online/max, Emblem, Hood, Gebiete und **Betreten**.
  - Höchstens 25 Spieler pro Gang.
  - Beim Beitreten läuft ein Wipe in der Teamfarbe über den Bildschirm.
- **Gang-Outfits statt GTA-Peds:** Alle spielen den Freemode-Charakter. Hoodie, Jogger, Sneaker und Cap kommen in der **Farbe der Gang** (Ballas lila, Families grün …). Gesicht, Frisur und Bart hängen an der User-ID, also sieht jeder Spieler immer gleich aus.
- **Hoods:**
  - Jede Gang **spawnt an ihrer Hood**: Grove Street, Brouge Avenue, Jamestown Street, Innocence Boulevard, El Burro Heights, Lost-MC-Clubhouse, Raven Slaughterhouse und La Fuente Blanca. Private Teams bekommen eigene Hoods.
  - An der Hood (und überall außerhalb von FFA und Gangwar) kann niemand schießen.
- **Garage (E):**
  - An der Hood parkst du Autos aus, freigeschaltet über dein Level.
  - Die Autos sind in Teamfarbe lackiert, mit Neon und Kennzeichen.
  - **F3** repariert dein Fahrzeug.
  - Gehst du ins FFA oder in einen Gangwar, verschwindet dein Auto wieder.
- **Hauptmenü (F2):**
  - **Free for all:** 8 Arenen gleichzeitig, jede mit Spielerlimit und einer Kartenvorschau
  - **Gangwar:** Gebiete angreifen und verteidigen, mit Live-Karte
  - **Rangliste**, **Regelwerk** und **Spieler online**
  - **Team:** privates Team gründen und verwalten
  - **Waffenshop:** mit Waffenbildern, einmal kaufen und für immer behalten
  - **Battlepass** mit 30 Leveln
  - **Einstellungen** und **Profil**
- **HUD:**
  - **Oben rechts:** Kills, Tode, K/D, XP-Balken, ID, Online-Zahl, Level und Geld
  - **Oben links:** Datum und Uhrzeit, darunter der Chat
  - **Unten rechts:** Munition und der **Spielzeit-Bonus** ($1.000 jede Stunde)
  - Die GTA-Minimap mit Leben und Weste bleibt wie gewohnt.
- **Eigener Chat (T):**
  - **Alle** oder **Team** (mit Tab umschalten), Befehle mit `/` und Vorschlägen
  - Spam-Schutz, Stummschalten und Verlauf mit Pfeil hoch/runter
  - Nachrichten anderer Ressourcen (z. B. txAdmin) erscheinen auch hier.
- **Admin-Menü (F6):**
  - **Spieler:** heilen, zur Hood schicken, Geld/XP/Premium geben, stummschalten, kicken, bannen (auch auf Zeit)
  - **Gebiete:** Besitzer setzen und Gangwars beenden
  - **Server:** Ankündigungen, alle heilen, FFA leeren, private Teams auflösen
  - **Banns:** Liste mit Aufheben
- **Motion Graphics:**
  - Fenster gleiten mit Blur rein, Karten erscheinen nacheinander.
  - Knöpfe bekommen beim Drüberfahren einen Glanz.
  - Kills „knallen" ins Bild, der Killfeed rutscht rein.
  - Beim Gangwar-Start kommt eine VS-Einblendung, beim Level-up ein Burst.
  - Meldungen haben einen Zeitbalken.
- **Bodyshot-System:** Der Server zählt jeden Treffer selbst. Kopf zählt wie Körper, und von voller HP plus Weste stirbt man nach 14–17 Treffern. Mk-II-Waffen machen mehr Schaden.

> Das Design ist an dem Aufbau angelehnt, den du mir gezeigt hast. Name, Logo und Grafiken von Cloud habe ich bewusst **nicht** kopiert: Der Server heißt `BODYSHOT GANGWAR` (in der `config.lua` änderbar), die Team-Embleme werden automatisch erzeugt, und für Logo, Bilder und Musik gibt es Ordner für deine eigenen Dateien (siehe unten).

## Tasten

| Taste | Was sie macht |
|---|---|
| **F1** | Teams (wechseln geht an der Hood) |
| **F2** | Hauptmenü. **Q** und **E** blättern durch die Seiten. |
| **F3** | Fahrzeug reparieren (30 s Wartezeit) |
| **E** | Garage, wenn du am blauen Auto-Symbol an deiner Hood stehst |
| **T** | Chat. **Tab** schaltet zwischen Alle und Team um. |
| **F6** | Admin-Menü (nur Admins) |
| **Esc** | Fenster schließen |

Jeder Spieler kann die Tasten unter **Settings → Key Bindings → FiveM** ändern.

## Gangwar-Regeln (alles in `config.lua` änderbar)

| | |
|---|---|
| Ablauf | Angriff → **60 s Vorbereitung** (kein Schaden) → **10 min Kampf** |
| Punkte | **3 Punkte pro Kill** in der Zone. Die Angreifer starten mit 1 Punkt. |
| Sieger | Wer mehr Punkte hat. Gewinnen die Angreifer, gehört ihnen das Gebiet. |
| Danach | 30 min Abklingzeit für das Gebiet |
| Freie Gebiete | gehören nach der Vorbereitung direkt dem Angreifer |
| Private Teams | Nur der Leader darf einen Angriff starten. |
| Einkommen | Alle 15 min bekommt jedes Teammitglied $500 pro Gebiet, das dem Team gehört. |

## Waffen, Treffer & Preise

Gerechnet wird mit 100 HP plus 100 Weste.

| Waffe | Treffer bis Kill | Preis |
|---|---|---|
| Compact Rifle, Assault Rifle | 17 | Startwaffen |
| Carbine Rifle / Bullpup Rifle / Gusenberg | 17 | $7.500 / $9.000 / $10.000 |
| Advanced Rifle / Special Carbine | 16 | $12.500 / $15.000 |
| **Assault / Carbine / Bullpup Rifle Mk II** | **15** | $25.000 / $30.000 / $30.000 |
| **Special Carbine Mk II** | **14** | $45.000 |

| Aktion | Geld | XP |
|---|---|---|
| FFA-Kill | $150 | 100 XP |
| Gangwar-Kill | $250 | 150 XP |
| Gangwar gewonnen / verloren | $3.000 / $750 | 1.000 / 300 XP |
| Jede Stunde Spielzeit | $1.000 | – |

Startgeld sind $2.500, ein privates Team kostet $25.000.

---

## Installation (Windows mit txAdmin)

### 1. Was du brauchst

- Einen **Windows-PC**, der läuft, solange gespielt wird, oder einen gemieteten Server (VPS). Normaler Webspace reicht dafür nicht.
- Einen **Cfx.re-Account** und einen kostenlosen **Lizenzkey**. Du bekommst ihn auf https://portal.cfx.re unter **Servers → Registration Keys → Generate key**.
- **7-Zip** zum Entpacken.

### 2. Server-Programm holen

1. Öffne https://runtime.fivem.net/artifacts/fivem/build_server_windows/master/ und lade bei **LATEST RECOMMENDED** die Datei `server.7z` herunter.
2. Lege den Ordner `C:\FXServer\server` an und entpacke `server.7z` hinein.

### 3. txAdmin einrichten

1. Starte `FXServer.exe`. Der Browser öffnet dann txAdmin.
2. Klicke auf **Link Account**, melde dich mit Cfx.re an und lege ein Admin-Passwort fest.
3. Gib einen Servernamen ein und wähle **Popular Recipes → CFX Default FiveM**.
4. Füge deinen Lizenzkey ein, klicke auf **Run Recipe** und dann auf **Save & Run Server**.

### 4. Gangwar einbauen

1. Stoppe den Server in txAdmin.
2. Kopiere den Ordner **`bodyshot_pvp`** aus dieser ZIP in den `resources`-Ordner deines Servers. Wo der liegt, siehst du in txAdmin unter **Settings → FXServer → Server Data Folder**.
   Wichtig: Die Datei `fxmanifest.lua` muss direkt in `resources\bodyshot_pvp\` liegen und nicht noch einen Ordner tiefer.
   **Hattest du schon eine alte Version, lösch den alten Ordner komplett und kopier den neuen rein.** Accounts, Teams und Gebiete bleiben erhalten, die liegen nicht im Ordner.
3. Öffne in txAdmin den **CFG Editor** und ändere drei Dinge:
   - Lösche die Zeilen `ensure basic-gamemode` und **`ensure chat`**. Der Server hat jetzt einen eigenen Chat.
   - Füge diese Zeile ein (für die Gang-Outfits und neuen Autos):
     ```
     sv_enforceGameBuild 3095
     ```
   - Füge am Ende diese Zeilen ein, falls sie noch fehlen:
     ```
     ensure bodyshot_pvp
     add_ace group.admin bodyshot_pvp.admin allow
     ```
   - Speichern.
4. Starte den Server. Spieler laden beim ersten Join einmal die neue Spielversion nach, das dauert ein paar Minuten.

**OneSync muss an sein**, sonst zählt kein einziger Treffer. In txAdmin ist das standardmäßig aktiv. Ist es aus, steht in der Konsole eine rote Warnung.

### 5. Freunde joinen lassen

- **Router:** Leite Port **30120** für **TCP und UDP** auf deinen PC weiter (Port Forwarding).
- **Firewall:** Beim ersten Start fragt Windows nach. Klicke dann auf **Allow access**.
  Wenn du das verpasst hast: **Windows Security → Firewall & network protection → Allow an app through firewall** und dort `FXServer.exe` für **Private** und **Public** erlauben.
- **Joinen:** Öffne FiveM, drücke **F8** und gib `connect DEINE-IP:30120` ein. Auf dem eigenen PC geht `connect localhost:30120`.

### Admin werden

1. Öffne in txAdmin **Players**, klicke auf dich und kopiere deine `license:…`-ID.
2. Füge im CFG Editor diese Zeile ein:
   ```
   add_principal identifier.license:DEINE_LICENSE group.admin
   ```
3. Danach öffnet **F6** im Spiel das Admin-Menü.

---

## Eigene Logos, Bilder und Musik

Alles optional. Fehlt eine Datei, zeigt der Server automatisch etwas Passendes an.

| Datei | Wofür |
|---|---|
| `html/img/logo.png` | Dein Logo, ersetzt den Schriftzug in allen Menüs und im Ladebildschirm |
| `html/img/teams/ballas.png` | Team-Logo im Teams-Fenster (Dateiname = Gang-ID; private Teams: `p1.png`, `p2.png` …) |
| `html/img/ffa/hafen.jpg` | Vorschaubild einer FFA-Arena (Dateiname = `key` der Arena) |
| `html/loading/img/character.png` | Großes Bild rechts im Ladebildschirm |
| `html/loading/music/*.mp3` | Musik im Ladebildschirm, zusätzlich in der `config.lua` bei `Config.Music` eintragen |

In jedem Ordner liegt eine `LIESMICH.txt` mit Größen und Beispielen. Nach dem Reinkopieren in der Live Console `ensure bodyshot_pvp` eingeben.

Servername, Untertitel, Willkommenstext, Discord-Link, Aufnahmepflicht-Text und Regelwerk stehen ganz oben in der `config.lua`.

## Hood-Punkte im Spiel verschieben

Die Hood-Punkte sind vorbelegt. Passt einer nicht, stell dich als Admin genau an die richtige Stelle und gib ein:

| Befehl | Was er setzt |
|---|---|
| `/sethood spawn` | Spawnpunkt deines Teams (Blickrichtung zählt) |
| `/sethood garage` | Garage (blaues Auto-Symbol, E drücken) |
| `/sethood car` | Wo das ausgeparkte Auto erscheint |
| `/sethood reset` | Zurück auf die Werte aus der `config.lua` |

Für ein anderes Team hängst du die Gang-ID an, z. B. `/sethood spawn vagos`, oder bei privaten Teams `p<Nummer>`, z. B. `/sethood garage p1`. Gespeichert wird sofort, auch über Neustarts.

## Befehle

**Spieler**

| Befehl | Was er macht |
|---|---|
| `/hood` | Zurück zu deiner Hood |
| `/t <Text>` | Nachricht nur an dein Team |
| `/kill` | Neu spawnen. Zählt als Tod. Wurdest du kurz vorher getroffen, bekommt der Schütze den Kill. |
| `/id` | Zeigt deine User-ID |
| `/stats [User-ID]` | Statistik von dir oder einem anderen Spieler |
| `/top` | Top 10 im Chat |
| `/pvpcoords` | Zeigt deine Position als fertige Zeile für die Config |

**Admin** (alles auch im Admin-Menü **F6**)

| Befehl | Was er macht |
|---|---|
| `/givemoney <User-ID> <Betrag>` | Geld geben (auch negativ zum Abziehen) |
| `/givexp <User-ID> <XP>` | Battlepass-XP geben |
| `/premium <User-ID> [0]` | Premium-Battlepass geben. Mit `0` wieder wegnehmen. |
| `/heal [User-ID]` | Volle HP und Weste |
| `/kick <User-ID> [Grund]` | Spieler kicken |
| `/ban <User-ID> <Stunden> [Grund]` | Bannen. `0` Stunden = für immer. |
| `/unban <User-ID>` | Bann aufheben |
| `/mute <User-ID> <Minuten>` | Im Chat stummschalten. `0` = aufheben. |
| `/announce <Text>` | Ankündigung für alle (Banner + Chat) |
| `/setzone <Gebiet> <Gang-ID / p<Nr> / frei>` | Besitzer eines Gebiets setzen, zum Beispiel `/setzone hafen ballas` |
| `/endwar <Gebiet>` | Laufenden Gangwar sofort auswerten |
| `/sethood …` | Hood-Punkte setzen (siehe oben) |

## Anpassen (`bodyshot_pvp/config.lua`)

Jede Einstellung ist dort auf Deutsch erklärt. Die wichtigsten:

- **Name, Texte, Links, Tasten:** ganz oben (`Config.ServerName`, `Config.Welcome`, `Config.Links`, `Config.Keys`, `Config.Connect`, `Config.Rules`)
- **Treffer bis Kill / Preise:** bei `Config.Weapons` (`shots = …`, `price = …`). `price = 0` macht eine Waffe zur Startwaffe.
- **Gangs:** Name, Kürzel, Farbe, Outfit-Farbe und Hood. `Config.TeamMax` legt fest, wie viele Spieler pro Gang erlaubt sind.
- **Outfits:** bei `Config.Outfits`. Dort stehen die Kleidungsstücke und welche Textur zu welcher Farbe gehört.
- **Garage:** bei `Config.Garage`. Dort legst du die Autos und ab welchem Level sie frei sind fest.
- **FFA-Arenen:** bei `Config.Arenas`, mit Name, Mitte, Radius und Spielerlimit
- **Gebiete und Gangwar:** bei `Config.Zones` und `Config.Gangwar`
- **Battlepass:** bei `Config.Battlepass`. **Neue Season:** Erhöhe `season = 2`, dann starten alle wieder bei Level 1.
- **Spielzeit-Bonus, Chat, Uhrzeit, Wetter, HUD-Standards:** stehen ebenfalls in der Datei. Die HUD-Einstellungen kann jeder Spieler zusätzlich selbst im Menü unter **Einstellungen** ändern.

Nach Änderungen gibst du in der Live Console `ensure bodyshot_pvp` ein oder startest den Server neu.

Accounts, Teams, Waffen, Battlepass-Fortschritt, Gebietsbesitzer, Hood-Punkte und Banns werden automatisch auf dem Server gespeichert. Du musst dafür keine Datenbank einrichten.

## Probleme?

| Problem | Lösung |
|---|---|
| Niemand nimmt Schaden | OneSync ist aus. Schau in der Konsole nach der roten Warnung. |
| Alle laufen in Standard-Klamotten rum | `sv_enforceGameBuild 3095` fehlt. Ohne die Zeile nimmt der Server ältere Ersatz-Kleidung. |
| Zwei Chats übereinander | `ensure chat` aus der server.cfg löschen. Die Konsole zeigt dazu auch einen Hinweis. |
| `Couldn't find resource bodyshot_pvp` | Der Ordner liegt falsch oder ist doppelt verschachtelt (siehe Schritt 4.2). |
| Doppelter oder komischer Spawn | `ensure basic-gamemode` aus der server.cfg löschen. |
| F1/F2 öffnet nichts | Erst einloggen und ein Team wählen. Prüf auch die Tasten unter **Settings → Key Bindings → FiveM**. |
| Spawn oder Garage an einer blöden Stelle | Mit `/sethood` an die richtige Stelle setzen (siehe oben). |
| Keine Auto- oder Waffenbilder | Die Bilder kommen von docs-backend.fivem.net. Ohne Internet zeigt der Server ein Symbol. |
