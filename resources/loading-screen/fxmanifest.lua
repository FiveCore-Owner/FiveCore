fx_version 'cerulean'
game 'gta5'

author 'FiveCore'
description 'FiveCore Loading Screen'
version '1.0.0'

loadscreen 'ui/index.html'
loadscreen_manual_shutdown 'yes'

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

files {
    'ui/index.html',
    'ui/style.css',
    'ui/app.js',
}
