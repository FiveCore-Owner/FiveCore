fx_version 'cerulean'
game 'gta5'

author 'FiveCore'
description 'FiveCore Custom Chat'
version '1.0.0'

-- Ersetzt den eingebauten FiveM-Chat
replace_level_loaders 'chat'

shared_scripts {
    '@core/shared/config.lua',
    '@core/shared/constants.lua',
    '@core/shared/locales.lua',
    '@core/locales/en.lua',
    '@core/locales/de.lua',
    '@core/locales/fr.lua',
    '@core/locales/zh.lua',
}

server_scripts {
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/app.js',
}
