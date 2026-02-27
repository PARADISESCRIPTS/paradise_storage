fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Paradise'
description 'Paradise Storages'
version '1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'scripting/server.lua',
    'scripting/sv_config.lua'
}

client_scripts {
    'scripting/client.lua'
}