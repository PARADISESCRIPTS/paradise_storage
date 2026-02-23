fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Paradise Storages'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'scripting/*.lua'
}

client_scripts {
    'scripting/*.lua'
}