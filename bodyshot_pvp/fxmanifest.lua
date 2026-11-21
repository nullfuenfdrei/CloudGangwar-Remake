fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'bodyshot_pvp'
description 'Gangwar mit Bodyshot-System: Login mit User-ID, GTA-Gangs + private Teams, Hoods mit Garage, FFA-Arenen, Gebiete erobern, Waffenshop, Battlepass, Tagesmissionen, Cases mit Waffen-Skins, 1v1-Duelle, Kopfgeld, eigener Chat, Admin-Menü, Ladebildschirm und MySQL (oxmysql)'
version '5.0.0'

shared_scripts {
    'config.lua',
    'shared/util.lua',
    'shared/weapons.lua',
    'shared/skins.lua',
    'shared/emotes.lua',
}

client_scripts {
    'client/bodyshot.lua',
    'client/outfit.lua',
    'client/main.lua',
    'client/hud.lua',
    'client/ui.lua',
    'client/features.lua',
    'client/garage.lua',
    'client/map.lua',
    'client/chat.lua',
    'client/admin.lua',
    'client/emotes.lua',
    'client/items.lua',
    'client/wardrobe.lua',
    'client/rpc.lua',
}

server_scripts {
    'server/db.lua',
    'server/state.lua',
    'server/logs.lua',
    'server/staff.lua',
    'server/anticheat.lua',
    'server/accounts.lua',
    'server/teams.lua',
    'server/hoods.lua',
    'server/modes.lua',
    'server/gangwar.lua',
    'server/combat.lua',
    'server/progress.lua',
    'server/missions.lua',
    'server/wheel.lua',
    'server/cases.lua',
    'server/bounty.lua',
    'server/duels.lua',
    'server/chat.lua',
    'server/admin.lua',
    'server/inventory.lua',
    'server/api.lua',
    'server/connect.lua',
    'server/commands.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

-- Ladebildschirm (wird geschlossen, sobald die Modus-Auswahl erscheint)
loadscreen 'html/loading/index.html'
loadscreen_manual_shutdown 'yes'
loadscreen_cursor 'yes'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/features.js',
    'html/i18n.js',
    'html/icons.js',
    'html/mapdata.js',
    'html/fonts/*.ttf',
    'html/loading/index.html',
    'html/loading/loading.css',
    'html/loading/loading.js',
    'html/loading/music/*',
    'html/loading/img/*',
    'html/img/*',
    'html/img/teams/*',
    'html/img/ffa/*',
    'html/img/brand/*',
}
