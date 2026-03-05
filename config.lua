Config = {}

-- Framework Selection ('qb-core' or 'esx')
Config.Framework = 'qb-core'

-- Target System ('ox_target' or 'qb-target')
Config.Target = 'ox_target'

Config.AdminPermissions = {
    -- Permission groups (QBCore permissions)
    groups = {
        'god',
        'admin',
        'superadmin'
    },
    
    -- Specific Citizen IDs who can use admin commands
    citizenids = {
        -- 'ABC12345',
        -- 'XYZ67890',
    },
    
    -- Specific licenses who can use admin commands
    licenses = {
        -- 'license:1234567890abcdef',
    },
    
    -- Specific Steam IDs who can use admin commands
    steamids = {
        -- 'steam:110000123456789',
    },
    
    -- Specific Discord IDs who can use admin commands
    discordids = {
        -- 'discord:123456789012345678',
    },
    
    -- Specific jobs who can use admin commands
    jobs = {
        -- 'police',
        -- 'admin',
    }
}

-- Default stash settings
Config.DefaultSlots = 50
Config.DefaultWeight = 100000 -- in grams (100kg)

-- Maximum limits
Config.MaxSlots = 200
Config.MaxWeight = 500000 -- in grams (500kg)

-- Stash types
Config.StashTypes = {
    PERSONAL = 'personal',
    JOB = 'job',
    GANG = 'gang',
    PASSCODE = 'passcode',
    ITEM = 'item' -- Requires specific item to open
}

-- Raid System
Config.RaidSystem = {
    enabled = true,
    allowedJobs = {'police', 'sheriff', 'fbi'}, -- Jobs that can raid stashes
    raidItem = 'advancedlockpick', -- Item required to raid
    raidableTypes = {
        Config.StashTypes.PERSONAL,
        Config.StashTypes.GANG,
        Config.StashTypes.PASSCODE,
        Config.StashTypes.ITEM
    },
    removeItemOnUse = true -- Remove raid item after use
}

-- Admin Commands
Config.Commands = {
    createStash = {
        name = 'createstash',
        description = 'Create a new stash'
    },
    manageStash = {
        name = 'managestash',
        description = 'Manage existing stashes'
    }
}