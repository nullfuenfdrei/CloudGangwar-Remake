-- =======================================================================
--  Emotes: Floss & Take the L
--
--  GTA hat diese Tänze nicht eingebaut. Die Animationen kommen als Datei
--  (.ycd) in den Ordner  bodyshot_pvp/stream/  – Dateiname = dict + ".ycd",
--  also stream/custom@floss.ycd und stream/custom@take_l.ycd.
--  Heißt die Animation in deinem Paket anders, hier dict/anim anpassen.
--
--  name  = /e <name>      loop = läuft, bis man sich bewegt oder /e stop
-- =======================================================================

EmoteList = {
    { name = 'floss', label = 'Floss',      group = 'Tänze', dict = 'custom@floss',  anim = 'floss',  loop = true },
    { name = 'takel', label = 'Take the L', group = 'Tänze', dict = 'custom@take_l', anim = 'take_l', loop = true },
}

EmoteByName = {}
for _, e in ipairs(EmoteList) do EmoteByName[e.name] = e end
EmoteByName['l'] = EmoteByName['takel']
EmoteByName['takethel'] = EmoteByName['takel']
