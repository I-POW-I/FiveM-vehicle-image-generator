fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'POW'
description 'POW Vehicle Image Generator - Automatic vehicle screenshot capture with Discord webhook integration'
version '1.3.0'

ui_page 'html/index.html'

shared_script 'config.lua'

client_script 'client/client.lua'
server_script 'server/server.lua'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

dependency 'screenshot-basic'

