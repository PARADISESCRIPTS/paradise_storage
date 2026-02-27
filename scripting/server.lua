local QBCore, ESX = nil, nil
local stashes = {}

if Config.Framework == 'qb-core' then
    QBCore = exports['qb-core']:GetCoreObject()
elseif Config.Framework == 'esx' then
    ESX = exports['es_extended']:getSharedObject()
end

CreateThread(function()
    while not MySQL do
        Wait(100)
    end
    
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS paradise_storages (
            id INT AUTO_INCREMENT PRIMARY KEY,
            stash_id VARCHAR(100) UNIQUE NOT NULL,
            label VARCHAR(255) NOT NULL,
            slots INT NOT NULL DEFAULT 50,
            weight INT NOT NULL DEFAULT 100000,
            coords TEXT NOT NULL,
            stash_type VARCHAR(50) NOT NULL,
            job VARCHAR(50) DEFAULT NULL,
            gang VARCHAR(50) DEFAULT NULL,
            cid VARCHAR(50) DEFAULT NULL,
            passcode VARCHAR(50) DEFAULT NULL,
            show_blip BOOLEAN DEFAULT FALSE,
            blip_sprite INT DEFAULT 478,
            blip_color INT DEFAULT 2,
            blip_scale FLOAT DEFAULT 0.8,
            spawn_prop BOOLEAN DEFAULT FALSE,
            prop_model VARCHAR(255) DEFAULT NULL,
            created_by VARCHAR(50) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])
    
    LoadStashes()
end)

function LoadStashes()
    MySQL.query('SELECT * FROM paradise_storages', {}, function(result)
        if result then
            for _, stash in ipairs(result) do
                stashes[stash.stash_id] = {
                    id = stash.id,
                    stash_id = stash.stash_id,
                    label = stash.label,
                    slots = stash.slots,
                    weight = stash.weight,
                    coords = json.decode(stash.coords),
                    stash_type = stash.stash_type,
                    job = stash.job,
                    gang = stash.gang,
                    cid = stash.cid,
                    passcode = stash.passcode,
                    show_blip = stash.show_blip or false,
                    blip_sprite = stash.blip_sprite or 478,
                    blip_color = stash.blip_color or 2,
                    blip_scale = stash.blip_scale or 0.8,
                    spawn_prop = stash.spawn_prop or false,
                    prop_model = stash.prop_model,
                    created_by = stash.created_by
                }
            end
            print('^2[Paradise Storages]^7 Loaded ' .. #result .. ' stashes')
        end
    end)
end

function GetPlayerIdentifierByType(source, identifierType)
    if identifierType == 'citizenid' then
        if Config.Framework == 'qb-core' then
            local Player = QBCore.Functions.GetPlayer(source)
            return Player and Player.PlayerData.citizenid
        elseif Config.Framework == 'esx' then
            local xPlayer = ESX.GetPlayerFromId(source)
            return xPlayer and xPlayer.identifier
        end
    end
    
    local identifiers = GetPlayerIdentifiers(source)
    for _, identifier in pairs(identifiers) do
        if string.find(identifier, identifierType .. ':') then
            return identifier
        end
    end
    return nil
end

function IsAdmin(source)
    if Config.Framework == 'qb-core' then
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return false end
        
        for _, group in ipairs(Config.AdminPermissions.groups) do
            if QBCore.Functions.HasPermission(source, group) then
                return true
            end
        end
        
        for _, cid in ipairs(Config.AdminPermissions.citizenids) do
            if Player.PlayerData.citizenid == cid then
                return true
            end
        end
        
        for _, job in ipairs(Config.AdminPermissions.jobs) do
            if Player.PlayerData.job.name == job then
                return true
            end
        end
    elseif Config.Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return false end
        
        for _, group in ipairs(Config.AdminPermissions.groups) do
            if xPlayer.getGroup() == group then
                return true
            end
        end
        
        for _, cid in ipairs(Config.AdminPermissions.citizenids) do
            if xPlayer.identifier == cid then
                return true
            end
        end
        
        for _, job in ipairs(Config.AdminPermissions.jobs) do
            if xPlayer.job.name == job then
                return true
            end
        end
    end
    
    for _, license in ipairs(Config.AdminPermissions.licenses) do
        local playerLicense = GetPlayerIdentifierByType(source, 'license')
        if playerLicense == license or playerLicense == 'license:' .. license then
            return true
        end
    end
    
    for _, steam in ipairs(Config.AdminPermissions.steamids) do
        local playerSteam = GetPlayerIdentifierByType(source, 'steam')
        if playerSteam == steam or playerSteam == 'steam:' .. steam then
            return true
        end
    end
    
    for _, discord in ipairs(Config.AdminPermissions.discordids) do
        local playerDiscord = GetPlayerIdentifierByType(source, 'discord')
        if playerDiscord == discord or playerDiscord == 'discord:' .. discord then
            return true
        end
    end
    
    return false
end

if Config.Framework == 'qb-core' then
    QBCore.Commands.Add(Config.Commands.createStash.name, Config.Commands.createStash.description, {}, false, function(source)
        if not IsAdmin(source) then
            TriggerClientEvent('ox_lib:notify', source, {type = 'error', description = 'You do not have permission'})
            return
        end
        
        TriggerClientEvent('paradise_storages:client:openCreateMenu', source)
    end)

    QBCore.Commands.Add(Config.Commands.manageStash.name, Config.Commands.manageStash.description, {}, false, function(source)
        if not IsAdmin(source) then
            TriggerClientEvent('ox_lib:notify', source, {type = 'error', description = 'You do not have permission'})
            return
        end
        
        TriggerClientEvent('paradise_storages:client:openManageMenu', source)
    end)
elseif Config.Framework == 'esx' then
    RegisterCommand(Config.Commands.createStash.name, function(source)
        if not IsAdmin(source) then
            TriggerClientEvent('ox_lib:notify', source, {type = 'error', description = 'You do not have permission'})
            return
        end
        
        TriggerClientEvent('paradise_storages:client:openCreateMenu', source)
    end)

    RegisterCommand(Config.Commands.manageStash.name, function(source)
        if not IsAdmin(source) then
            TriggerClientEvent('ox_lib:notify', source, {type = 'error', description = 'You do not have permission'})
            return
        end
        
        TriggerClientEvent('paradise_storages:client:openManageMenu', source)
    end)
end

lib.callback.register('paradise_storages:server:getStashes', function(source)
    return stashes
end)

RegisterNetEvent('paradise_storages:server:createStash', function(data)
    local src = source
    if not IsAdmin(src) then return end
    
    local creatorId = nil
    if Config.Framework == 'qb-core' then
        local Player = QBCore.Functions.GetPlayer(src)
        creatorId = Player and Player.PlayerData.citizenid
    elseif Config.Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(src)
        creatorId = xPlayer and xPlayer.identifier
    end
    
    local stashId = 'stash_' .. math.random(10000, 99999)
    
    while stashes[stashId] do
        stashId = 'stash_' .. math.random(10000, 99999)
    end
    
    MySQL.insert('INSERT INTO paradise_storages (stash_id, label, slots, weight, coords, stash_type, job, gang, cid, passcode, show_blip, blip_sprite, blip_color, blip_scale, spawn_prop, prop_model, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        {stashId, data.label, data.slots, data.weight, json.encode(data.coords), data.stash_type, data.job, data.gang, data.cid, data.passcode, data.show_blip or false, data.blip_sprite or 478, data.blip_color or 2, data.blip_scale or 0.8, data.spawn_prop or false, data.prop_model, creatorId},
        function(id)
            if id then
                stashes[stashId] = {
                    id = id,
                    stash_id = stashId,
                    label = data.label,
                    slots = data.slots,
                    weight = data.weight,
                    coords = data.coords,
                    stash_type = data.stash_type,
                    job = data.job,
                    gang = data.gang,
                    cid = data.cid,
                    passcode = data.passcode,
                    show_blip = data.show_blip or false,
                    blip_sprite = data.blip_sprite or 478,
                    blip_color = data.blip_color or 2,
                    blip_scale = data.blip_scale or 0.8,
                    spawn_prop = data.spawn_prop or false,
                    prop_model = data.prop_model,
                    created_by = creatorId
                }
                
                TriggerClientEvent('paradise_storages:client:refreshStashes', -1)
                TriggerClientEvent('ox_lib:notify', src, {type = 'success', description = 'Stash created successfully!'})
            else
                TriggerClientEvent('ox_lib:notify', src, {type = 'error', description = 'Failed to create stash'})
            end
        end
    )
end)

RegisterNetEvent('paradise_storages:server:updateStash', function(stashId, data)
    local src = source
    if not IsAdmin(src) then return end
    
    if not stashes[stashId] then
        TriggerClientEvent('ox_lib:notify', src, {type = 'error', description = 'Stash not found'})
        return
    end
    
    local spawnProp = data.spawn_prop
    local propModel = data.prop_model
    
    if spawnProp == nil then
        spawnProp = stashes[stashId].spawn_prop
    end
    
    if not propModel then
        propModel = stashes[stashId].prop_model
    end
    
    MySQL.update('UPDATE paradise_storages SET label = ?, slots = ?, weight = ?, coords = ?, stash_type = ?, job = ?, gang = ?, cid = ?, passcode = ?, show_blip = ?, blip_sprite = ?, blip_color = ?, blip_scale = ?, spawn_prop = ?, prop_model = ? WHERE stash_id = ?',
        {data.label, data.slots, data.weight, json.encode(data.coords), data.stash_type, data.job, data.gang, data.cid, data.passcode, data.show_blip or false, data.blip_sprite or 478, data.blip_color or 2, data.blip_scale or 0.8, spawnProp, propModel, stashId},
        function(affectedRows)
            if affectedRows > 0 then
                stashes[stashId].label = data.label
                stashes[stashId].slots = data.slots
                stashes[stashId].weight = data.weight
                stashes[stashId].coords = data.coords
                stashes[stashId].stash_type = data.stash_type
                stashes[stashId].job = data.job
                stashes[stashId].gang = data.gang
                stashes[stashId].cid = data.cid
                stashes[stashId].passcode = data.passcode
                stashes[stashId].show_blip = data.show_blip or false
                stashes[stashId].blip_sprite = data.blip_sprite or 478
                stashes[stashId].blip_color = data.blip_color or 2
                stashes[stashId].blip_scale = data.blip_scale or 0.8
                stashes[stashId].spawn_prop = spawnProp
                stashes[stashId].prop_model = propModel
                
                TriggerClientEvent('paradise_storages:client:refreshStashes', -1)
                TriggerClientEvent('ox_lib:notify', src, {type = 'success', description = 'Stash updated successfully!'})
            else
                TriggerClientEvent('ox_lib:notify', src, {type = 'error', description = 'Failed to update stash'})
            end
        end
    )
end)

RegisterNetEvent('paradise_storages:server:deleteStash', function(stashId)
    local src = source
    if not IsAdmin(src) then return end
    
    if not stashes[stashId] then
        TriggerClientEvent('ox_lib:notify', src, {type = 'error', description = 'Stash not found'})
        return
    end
    
    MySQL.query('DELETE FROM paradise_storages WHERE stash_id = ?', {stashId}, function(result)
        if result.affectedRows > 0 then
            stashes[stashId] = nil
            TriggerClientEvent('paradise_storages:client:refreshStashes', -1)
            TriggerClientEvent('ox_lib:notify', src, {type = 'success', description = 'Stash deleted successfully!'})
        else
            TriggerClientEvent('ox_lib:notify', src, {type = 'error', description = 'Failed to delete stash'})
        end
    end)
end)

lib.callback.register('paradise_storages:server:checkAccess', function(source, stashId)
    local stash = stashes[stashId]
    if not stash then return false end
    
    if IsAdmin(source) then return true end
    
    if Config.Framework == 'qb-core' then
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return false end
        
        if stash.stash_type == Config.StashTypes.JOB then
            return Player.PlayerData.job.name == stash.job
        elseif stash.stash_type == Config.StashTypes.GANG then
            return Player.PlayerData.gang.name == stash.gang
        elseif stash.stash_type == Config.StashTypes.PERSONAL then
            return Player.PlayerData.citizenid == stash.cid
        elseif stash.stash_type == Config.StashTypes.PASSCODE then
            return true
        end
    elseif Config.Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return false end
        
        if stash.stash_type == Config.StashTypes.JOB then
            return xPlayer.job.name == stash.job
        elseif stash.stash_type == Config.StashTypes.GANG then
            -- ESX doesn't have gangs by default, add yours over here
            return false
        elseif stash.stash_type == Config.StashTypes.PERSONAL then
            return xPlayer.identifier == stash.cid
        elseif stash.stash_type == Config.StashTypes.PASSCODE then
            return true
        end
    end
    
    return false
end)

lib.callback.register('paradise_storages:server:verifyPasscode', function(source, stashId, passcode)
    local stash = stashes[stashId]
    if not stash then return false end
    
    return stash.passcode == passcode
end)

RegisterNetEvent('paradise_storages:server:openStash', function(stashId, passcodeVerified)
    local src = source
    local stash = stashes[stashId]
    
    if not stash then
        TriggerClientEvent('ox_lib:notify', src, {type = 'error', description = 'Stash not found'})
        return
    end
    
    local hasAccess = false
    
    if Config.Framework == 'qb-core' then
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return end
        
        if stash.stash_type == Config.StashTypes.JOB then
            hasAccess = Player.PlayerData.job.name == stash.job
        elseif stash.stash_type == Config.StashTypes.GANG then
            hasAccess = Player.PlayerData.gang.name == stash.gang
        elseif stash.stash_type == Config.StashTypes.PERSONAL then
            hasAccess = Player.PlayerData.citizenid == stash.cid
        elseif stash.stash_type == Config.StashTypes.PASSCODE then
            hasAccess = passcodeVerified == true
        end
    elseif Config.Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return end
        
        if stash.stash_type == Config.StashTypes.JOB then
            hasAccess = xPlayer.job.name == stash.job
        elseif stash.stash_type == Config.StashTypes.GANG then
            hasAccess = false -- ESX doesn't have gangs by default
        elseif stash.stash_type == Config.StashTypes.PERSONAL then
            hasAccess = xPlayer.identifier == stash.cid
        elseif stash.stash_type == Config.StashTypes.PASSCODE then
            hasAccess = passcodeVerified == true
        end
    end
    
    if not hasAccess then
        TriggerClientEvent('ox_lib:notify', src, {type = 'error', description = 'You do not have access to this storage'})
        return
    end
    
    exports.ox_inventory:RegisterStash(stashId, stash.label, stash.slots, stash.weight, false)
    TriggerClientEvent('ox_inventory:openInventory', src, 'stash', stashId)
end)
