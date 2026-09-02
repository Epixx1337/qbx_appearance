fx_version 'cerulean'
game 'gta5'

name 'qbx_appearance'
description 'Collection-native appearance, outfits and clothing studio for Qbox'
repository 'https://github.com/Epixx1337/qbx_appearance'
version '0.2.1'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
    'client/compat.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/compat.lua',
    'server/screenshot.js',
}

files {
    'config/shared.lua',
    'config/client.lua',
    'config/peds.lua',
    'config/tattoos.lua',
    'client/modules/*.lua',
    'shared/*.lua',
    'locales/*.json',
    'web/build/index.html',
    'web/build/**/*',
    'screenshots/faces/*.webp',
    'screenshots/peds/*.webp',
    'screenshots/clothing/masks/*.webp',
    'screenshots/clothing/hair/*.webp',
    'screenshots/clothing/arms/*.webp',
    'screenshots/clothing/pants/*.webp',
    'screenshots/clothing/bags/*.webp',
    'screenshots/clothing/shoes/*.webp',
    'screenshots/clothing/accessories/*.webp',
    'screenshots/clothing/undershirts/*.webp',
    'screenshots/clothing/armor/*.webp',
    'screenshots/clothing/decals/*.webp',
    'screenshots/clothing/tops/*.webp',
    'screenshots/clothing/hats/*.webp',
    'screenshots/clothing/glasses/*.webp',
    'screenshots/clothing/ears/*.webp',
    'screenshots/clothing/watches/*.webp',
    'screenshots/clothing/bracelets/*.webp',
}

ui_page 'web/build/index.html'

dependencies {
    'qbx_core',
    'ox_lib',
    'oxmysql',
    'ox_inventory',
    'screencapture',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
node_version '22'
