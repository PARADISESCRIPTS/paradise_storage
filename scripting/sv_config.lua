Paradise = {}

Paradise.Discord = {
    enabled = true,
    webhook = 'YOUR_WEBHOOK', -- Add your Discord webhook URL here
    botName = 'Paradise Storages',
    color = 3447003, -- Blue color
    footer = 'Paradise Storages Logs',
    
    -- Log types
    logs = {
        createStash = true,
        updateStash = true,
        deleteStash = true,
        accessStash = true
    }
}