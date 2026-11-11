fx_version 'cerulean'
game 'gta5'

description 'KOTH admin panel, reports, career stats, bounty, prestige and killstreaks (server: koth-main/server/admin.lua + stats.lua)'

dependency 'koth-main'

ui_page 'ui/index.html'

client_scripts {
    'client/main.lua',
    'client/admin.lua',
    'client/report.lua',
    'client/career.lua',
    'client/bounty.lua',
    'client/killstreak.lua',
}

files {
    'ui/index.html',
    'ui/style.css',
    'ui/app.js',
}
