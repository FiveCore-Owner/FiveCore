fx_version 'cerulean'
game 'gta5'

author 'FiveCore'
description 'FiveCore Inventory — 45 Slots, Hotbar, Weapon Wheel Block'
version '1.0.0'

shared_scripts {
    '@core/shared/config.lua',
    '@core/shared/constants.lua',
    '@core/shared/locales.lua',
    '@core/locales/en.lua',
    '@core/locales/de.lua',
    '@core/locales/fr.lua',
    '@core/locales/zh.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/app.js',
}
