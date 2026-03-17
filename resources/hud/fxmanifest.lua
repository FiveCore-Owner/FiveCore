fx_version 'cerulean'
game 'gta5'

author 'FiveCore'
description 'FiveCore HUD'
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

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/app.js',
}

-- Stream-Ordner: FiveM streamt .ytd und .gfx Dateien aus dem stream/ Ordner automatisch.
-- minimap.ytd  → ersetzt die Minimap-Textur im Spiel
-- minimap.gfx  → ersetzt das Minimap-Scaleform-UI
-- Beide Dateien werden automatisch geladen, keine weiteren Einträge nötig.
