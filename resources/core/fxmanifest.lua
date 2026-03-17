fx_version 'cerulean'
game 'gta5'

author 'FiveCore'
description 'FiveCore Custom Framework — Core'
version '1.0.1'

shared_scripts {
    'shared/config.lua',
    'shared/constants.lua',
    'shared/locales.lua',
    'locales/en.lua',
    'locales/de.lua',
    'locales/fr.lua',
    'locales/zh.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/db.lua',
    'server/security.lua',
    'server/players.lua',
    'server/events.lua',
    'server/main.lua',
}

client_scripts {
    'client/state.lua',
    'client/utils.lua',
}
