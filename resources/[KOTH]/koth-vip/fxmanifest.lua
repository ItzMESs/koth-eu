fx_version 'cerulean'
game 'gta5'

description 'KOTH VIP menu (server logic: koth-main/server/vip.lua)'

dependency 'koth-main'

ui_page 'ui/index.html'

client_scripts {
    'client/weapons.lua',
    'client/vehicle.lua',
    'client/main.lua',
}

files {
    'ui/index.html',
    'ui/style.css',
    'ui/script.js',
}
