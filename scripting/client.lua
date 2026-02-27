local QBCore, ESX = nil, nil
local stashes = {}
local stashBlips = {}
local stashPoints = {}
local stashProps = {}
local creationLaser = false
local stashCreationData = nil

if Config.Framework == 'qb-core' then
    QBCore = exports['qb-core']:GetCoreObject()
elseif Config.Framework == 'esx' then
    ESX = exports['es_extended']:getSharedObject()
end

function LoadStashes()
    stashes = lib.callback.await('paradise_storages:server:getStashes', false)
    CreateStashPoints()
end

CreateThread(function()
    Wait(1000)
    LoadStashes()
end)

RegisterNetEvent('paradise_storages:client:refreshStashes', function()
    LoadStashes()
end)

function CreateStashPoints()
    for _, blip in pairs(stashBlips) do
        RemoveBlip(blip)
    end
    stashBlips = {}
    
    for stashId, _ in pairs(stashPoints) do
        if Config.Target == 'ox_target' then
            exports.ox_target:removeZone(stashId)
        elseif Config.Target == 'qb-target' then
            exports['qb-target']:RemoveZone(stashId)
        end
    end
    stashPoints = {}
    
    for stashId, prop in pairs(stashProps) do
        if DoesEntityExist(prop) then
            SetEntityAsMissionEntity(prop, false, true)
            DeleteEntity(prop)
        end
    end
    stashProps = {}
    
    Wait(100)
    
    for stashId, stash in pairs(stashes) do
        if stash.spawn_prop and stash.prop_model then
            CreateThread(function()
                local propHash = GetHashKey(stash.prop_model)
                RequestModel(propHash)
                
                local timeout = 0
                while not HasModelLoaded(propHash) and timeout < 100 do
                    Wait(10)
                    timeout = timeout + 1
                end
                
                if HasModelLoaded(propHash) then
                    local prop = CreateObject(propHash, stash.coords.x, stash.coords.y, stash.coords.z, false, false, false)
                    
                    if DoesEntityExist(prop) then
                        FreezeEntityPosition(prop, true)
                        SetEntityAsMissionEntity(prop, true, true)
                        SetEntityCollision(prop, true, true)
                        stashProps[stashId] = prop
                    end
                    
                    SetModelAsNoLongerNeeded(propHash)
                end
            end)
        end
        
        if Config.Target == 'ox_target' then
            exports.ox_target:addSphereZone({
                name = stashId,
                coords = vector3(stash.coords.x, stash.coords.y, stash.coords.z),
                radius = 1.5,
                debug = false,
                options = {
                    {
                        name = 'open_storage',
                        icon = 'fas fa-box',
                        label = 'Open ' .. stash.label,
                        onSelect = function()
                            OpenStash(stashId)
                        end
                    }
                }
            })
        elseif Config.Target == 'qb-target' then
            exports['qb-target']:AddBoxZone(stashId, vector3(stash.coords.x, stash.coords.y, stash.coords.z), 1.5, 1.5, {
                name = stashId,
                heading = 0,
                debugPoly = false,
                minZ = stash.coords.z - 1.0,
                maxZ = stash.coords.z + 1.0,
            }, {
                options = {
                    {
                        type = "client",
                        icon = "fas fa-box",
                        label = "Open " .. stash.label,
                        action = function()
                            OpenStash(stashId)
                        end,
                    }
                },
                distance = 2.0
            })
        end
        
        stashPoints[stashId] = true
        
        if stash.show_blip then
            local blip = AddBlipForCoord(stash.coords.x, stash.coords.y, stash.coords.z)
            SetBlipSprite(blip, stash.blip_sprite or 478)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, stash.blip_scale or 0.8)
            SetBlipColour(blip, stash.blip_color or 2)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(stash.label)
            EndTextCommandSetBlipName(blip)
            stashBlips[stashId] = blip
        end
    end
end

function OpenStash(stashId)
    local hasAccess = lib.callback.await('paradise_storages:server:checkAccess', false, stashId)
    
    if not hasAccess then
        lib.notify({type = 'error', description = 'You do not have access to this storage'})
        return
    end
    
    local stash = stashes[stashId]
    local passcodeVerified = false
    
    if stash.stash_type == Config.StashTypes.PASSCODE then
        local input = lib.inputDialog('Enter Passcode', {
            {type = 'input', label = 'Passcode', description = 'Enter the storage passcode', required = true, password = true}
        })
        
        if not input then return end
        
        local verified = lib.callback.await('paradise_storages:server:verifyPasscode', false, stashId, input[1])
        
        if not verified then
            lib.notify({type = 'error', description = 'Incorrect passcode'})
            return
        end
        
        passcodeVerified = true
    end
    
    TriggerServerEvent('paradise_storages:server:openStash', stashId, passcodeVerified)
end


RegisterNetEvent('paradise_storages:client:openCreateMenu', function()
    local input = lib.inputDialog('Create Storage', {
        {type = 'input', label = 'Storage Label', description = 'Display name for the storage', required = true},
        {type = 'number', label = 'Slots', description = 'Number of slots (Max: ' .. Config.MaxSlots .. ')', default = Config.DefaultSlots, required = true, min = 1, max = Config.MaxSlots},
        {type = 'number', label = 'Weight (grams)', description = 'Maximum weight capacity (Max: ' .. Config.MaxWeight .. 'g)', default = Config.DefaultWeight, required = true, min = 1000, max = Config.MaxWeight},
        {type = 'select', label = 'Storage Type', description = 'Select storage access type', required = true, options = {
            {value = Config.StashTypes.PERSONAL, label = 'Personal (CID Based)'},
            {value = Config.StashTypes.JOB, label = 'Job Based'},
            {value = Config.StashTypes.GANG, label = 'Gang Based'},
            {value = Config.StashTypes.PASSCODE, label = 'Passcode Protected'}
        }},
        {type = 'checkbox', label = 'Show Blip on Map', description = 'Display a blip for this storage', checked = false},
        {type = 'checkbox', label = 'Spawn Prop', description = 'Spawn a prop at storage location', checked = false}
    })
    
    if not input then return end
    
    local stashType = input[4]
    local showBlip = input[5]
    local spawnProp = input[6]
    local additionalData = {}
    local blipData = {}
    local propData = {}
    
    if stashType == Config.StashTypes.JOB then
        local jobInput = lib.inputDialog('Job Configuration', {
            {type = 'input', label = 'Job Name', description = 'Enter job name (e.g., police)', required = true}
        })
        if not jobInput then return end
        additionalData.job = jobInput[1]
        
    elseif stashType == Config.StashTypes.GANG then
        local gangInput = lib.inputDialog('Gang Configuration', {
            {type = 'input', label = 'Gang Name', description = 'Enter gang name (e.g., ballas)', required = true}
        })
        if not gangInput then return end
        additionalData.gang = gangInput[1]
        
    elseif stashType == Config.StashTypes.PERSONAL then
        local cidInput = lib.inputDialog('Personal Configuration', {
            {type = 'input', label = 'Citizen ID', description = 'Enter the citizen ID', required = true}
        })
        if not cidInput then return end
        additionalData.cid = cidInput[1]
        
    elseif stashType == Config.StashTypes.PASSCODE then
        local passcodeInput = lib.inputDialog('Passcode Configuration', {
            {type = 'input', label = 'Passcode', description = 'Set a passcode for the storage', required = true, password = true}
        })
        if not passcodeInput then return end
        additionalData.passcode = passcodeInput[1]
    end
    
    if showBlip then
        local blipInput = lib.inputDialog('Blip Configuration', {
            {type = 'number', label = 'Blip Sprite', description = 'Blip icon ID', default = 478, required = true},
            {type = 'number', label = 'Blip Color', description = 'Blip color ID', default = 2, required = true},
            {type = 'number', label = 'Blip Scale', description = 'Blip size (0.5 - 2.0)', default = 0.8, required = true, min = 0.5, max = 2.0}
        })
        if blipInput then
            blipData.blip_sprite = blipInput[1]
            blipData.blip_color = blipInput[2]
            blipData.blip_scale = blipInput[3]
        end
    end
    
    if spawnProp then
        local propInput = lib.inputDialog('Prop Configuration', {
            {type = 'input', label = 'Prop Model', description = 'Enter prop model name (e.g., prop_box_wood02a)', required = true}
        })
        if propInput then
            propData.prop_model = propInput[1]
        end
    end
    
    stashCreationData = {
        label = input[1],
        slots = input[2],
        weight = input[3],
        stash_type = stashType,
        job = additionalData.job,
        gang = additionalData.gang,
        cid = additionalData.cid,
        passcode = additionalData.passcode,
        show_blip = showBlip,
        blip_sprite = blipData.blip_sprite or 478,
        blip_color = blipData.blip_color or 2,
        blip_scale = blipData.blip_scale or 0.8,
        spawn_prop = spawnProp,
        prop_model = propData.prop_model
    }
    
    lib.notify({type = 'info', description = 'Use the laser to place the storage. Press E to confirm, X to cancel', duration = 5000})
    ToggleCreationLaser()
end)

RegisterNetEvent('paradise_storages:client:openManageMenu', function()
    local options = {}
    
    for stashId, stash in pairs(stashes) do
        local typeLabel = stash.stash_type
        if stash.stash_type == Config.StashTypes.JOB then
            typeLabel = 'Job: ' .. (stash.job or 'N/A')
        elseif stash.stash_type == Config.StashTypes.GANG then
            typeLabel = 'Gang: ' .. (stash.gang or 'N/A')
        elseif stash.stash_type == Config.StashTypes.PERSONAL then
            typeLabel = 'Personal: ' .. (stash.cid or 'N/A')
        elseif stash.stash_type == Config.StashTypes.PASSCODE then
            typeLabel = 'Passcode Protected'
        end
        
        table.insert(options, {
            title = stash.label,
            description = typeLabel .. ' | Slots: ' .. stash.slots .. ' | Weight: ' .. stash.weight .. 'g',
            icon = 'box',
            onSelect = function()
                OpenStashManagementOptions(stashId)
            end
        })
    end
    
    if #options == 0 then
        lib.notify({type = 'error', description = 'No stashes found'})
        return
    end
    
    lib.registerContext({
        id = 'manage_stashes',
        title = 'Manage Stashes',
        options = options
    })
    
    lib.showContext('manage_stashes')
end)

function OpenStashManagementOptions(stashId)
    local stash = stashes[stashId]
    
    lib.registerContext({
        id = 'stash_options',
        title = stash.label,
        menu = 'manage_stashes',
        options = {
            {
                title = 'Edit Stash',
                description = 'Modify stash settings',
                icon = 'pen',
                onSelect = function()
                    EditStash(stashId)
                end
            },
            {
                title = 'Teleport to Stash',
                description = 'Teleport to stash location',
                icon = 'location-dot',
                onSelect = function()
                    SetEntityCoords(PlayerPedId(), stash.coords.x, stash.coords.y, stash.coords.z)
                    lib.notify({type = 'success', description = 'Teleported to stash'})
                end
            },
            {
                title = 'Update Location',
                description = 'Use laser to set new location',
                icon = 'map-pin',
                onSelect = function()
                    UpdateStashLocation(stashId)
                end
            },
            {
                title = 'Delete Stash',
                description = 'Permanently delete this stash',
                icon = 'trash',
                iconColor = 'red',
                onSelect = function()
                    local alert = lib.alertDialog({
                        header = 'Delete Stash',
                        content = 'Are you sure you want to delete ' .. stash.label .. '? This cannot be undone.',
                        centered = true,
                        cancel = true
                    })
                    
                    if alert == 'confirm' then
                        TriggerServerEvent('paradise_storages:server:deleteStash', stashId)
                    end
                end
            }
        }
    })
    
    lib.showContext('stash_options')
end

function EditStash(stashId)
    local stash = stashes[stashId]
    
    local input = lib.inputDialog('Edit Stash', {
        {type = 'input', label = 'Stash Label', default = stash.label, required = true},
        {type = 'number', label = 'Slots', description = 'Max: ' .. Config.MaxSlots, default = stash.slots, required = true, min = 1, max = Config.MaxSlots},
        {type = 'number', label = 'Weight (grams)', description = 'Max: ' .. Config.MaxWeight .. 'g', default = stash.weight, required = true, min = 1000, max = Config.MaxWeight},
        {type = 'select', label = 'Stash Type', default = stash.stash_type, required = true, options = {
            {value = Config.StashTypes.PERSONAL, label = 'Personal (CID Based)'},
            {value = Config.StashTypes.JOB, label = 'Job Based'},
            {value = Config.StashTypes.GANG, label = 'Gang Based'},
            {value = Config.StashTypes.PASSCODE, label = 'Passcode Protected'}
        }}
    })
    
    if not input then return end
    
    local stashType = input[4]
    local additionalData = {}
    
    if stashType == Config.StashTypes.JOB then
        local jobInput = lib.inputDialog('Job Configuration', {
            {type = 'input', label = 'Job Name', default = stash.job, required = true}
        })
        if not jobInput then return end
        additionalData.job = jobInput[1]
        
    elseif stashType == Config.StashTypes.GANG then
        local gangInput = lib.inputDialog('Gang Configuration', {
            {type = 'input', label = 'Gang Name', default = stash.gang, required = true}
        })
        if not gangInput then return end
        additionalData.gang = gangInput[1]
        
    elseif stashType == Config.StashTypes.PERSONAL then
        local cidInput = lib.inputDialog('Personal Configuration', {
            {type = 'input', label = 'Citizen ID', default = stash.cid, required = true}
        })
        if not cidInput then return end
        additionalData.cid = cidInput[1]
        
    elseif stashType == Config.StashTypes.PASSCODE then
        local passcodeInput = lib.inputDialog('Passcode Configuration', {
            {type = 'input', label = 'Passcode', default = stash.passcode, required = true, password = true}
        })
        if not passcodeInput then return end
        additionalData.passcode = passcodeInput[1]
    end
    
    local data = {
        label = input[1],
        slots = input[2],
        weight = input[3],
        stash_type = stashType,
        coords = stash.coords,
        job = additionalData.job,
        gang = additionalData.gang,
        cid = additionalData.cid,
        passcode = additionalData.passcode,
        show_blip = stash.show_blip,
        blip_sprite = stash.blip_sprite,
        blip_color = stash.blip_color,
        blip_scale = stash.blip_scale,
        spawn_prop = stash.spawn_prop,
        prop_model = stash.prop_model
    }
    
    TriggerServerEvent('paradise_storages:server:updateStash', stashId, data)
end

function UpdateStashLocation(stashId)
    local stash = stashes[stashId]
    if not stash then return end
    
    lib.notify({type = 'info', description = 'Use the laser to set new location. Press E to confirm, X to cancel', duration = 5000})
    
    local updateLaser = true
    CreateThread(function()
        while updateLaser do
            local hit, coords = DrawLaser('PRESS ~g~E~w~ TO UPDATE LOCATION\nPRESS ~r~X~w~ TO CANCEL', {r = 2, g = 241, b = 181, a = 200})
            
            if IsControlJustReleased(0, 38) then -- E key
                updateLaser = false
                if hit then
                    if stashProps[stashId] and DoesEntityExist(stashProps[stashId]) then
                        SetEntityAsMissionEntity(stashProps[stashId], false, true)
                        DeleteEntity(stashProps[stashId])
                        stashProps[stashId] = nil
                    end
                    
                    local data = {
                        label = stash.label,
                        slots = stash.slots,
                        weight = stash.weight,
                        stash_type = stash.stash_type,
                        coords = {x = coords.x, y = coords.y, z = coords.z},
                        job = stash.job,
                        gang = stash.gang,
                        cid = stash.cid,
                        passcode = stash.passcode,
                        show_blip = stash.show_blip,
                        blip_sprite = stash.blip_sprite,
                        blip_color = stash.blip_color,
                        blip_scale = stash.blip_scale,
                        spawn_prop = stash.spawn_prop,
                        prop_model = stash.prop_model
                    }
                    
                    TriggerServerEvent('paradise_storages:server:updateStash', stashId, data)
                    lib.notify({type = 'success', description = 'Location updated successfully!'})
                else
                    lib.notify({type = 'error', description = 'Invalid placement location'})
                end
            elseif IsControlJustReleased(0, 73) then -- X key
                updateLaser = false
                lib.notify({type = 'error', description = 'Location update cancelled'})
            end
            
            Wait(0)
        end
    end)
end


function ToggleCreationLaser()
    creationLaser = not creationLaser
    if creationLaser then
        CreateThread(function()
            while creationLaser do
                local hit, coords = DrawLaser('PRESS ~g~E~w~ TO PLACE STORAGE\nPRESS ~r~X~w~ TO CANCEL', {r = 2, g = 241, b = 181, a = 200})
                
                if IsControlJustReleased(0, 38) then -- E key
                    creationLaser = false
                    if hit and stashCreationData then
                        stashCreationData.coords = {x = coords.x, y = coords.y, z = coords.z}
                        TriggerServerEvent('paradise_storages:server:createStash', stashCreationData)
                        stashCreationData = nil
                        lib.notify({type = 'success', description = 'Storage placed successfully!'})
                    else
                        lib.notify({type = 'error', description = 'Invalid placement location'})
                    end
                elseif IsControlJustReleased(0, 73) then -- X key
                    creationLaser = false
                    stashCreationData = nil
                    lib.notify({type = 'error', description = 'Storage placement cancelled'})
                end
                
                Wait(0)
            end
        end)
    end
end

function DrawLaser(message, color)
    local hit, coords = RayCastGamePlayCamera(20.0)
    Draw2DText(message, 4, {255, 255, 255}, 0.4, 0.43, 0.888 + 0.025)
    
    if hit then
        local position = GetEntityCoords(PlayerPedId())
        DrawLine(position.x, position.y, position.z, coords.x, coords.y, coords.z, color.r, color.g, color.b, color.a)
        DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.1, 0.1, 0.1, color.r, color.g, color.b, color.a, false, true, 2, nil, nil, false)
    end
    
    return hit, coords
end

function RotationToDirection(rotation)
    local adjustedRotation = {
        x = (math.pi / 180) * rotation.x,
        y = (math.pi / 180) * rotation.y,
        z = (math.pi / 180) * rotation.z
    }
    local direction = {
        x = -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        y = math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        z = math.sin(adjustedRotation.x)
    }
    return direction
end

function RayCastGamePlayCamera(distance)
    local cameraRotation = GetGameplayCamRot()
    local cameraCoord = GetGameplayCamCoord()
    local direction = RotationToDirection(cameraRotation)
    local destination = {
        x = cameraCoord.x + direction.x * distance,
        y = cameraCoord.y + direction.y * distance,
        z = cameraCoord.z + direction.z * distance
    }
    local _, hit, endCoords, _, _ = GetShapeTestResult(StartShapeTestRay(cameraCoord.x, cameraCoord.y, cameraCoord.z, destination.x, destination.y, destination.z, -1, PlayerPedId(), 0))
    return hit == 1, endCoords
end

function Draw2DText(content, font, colour, scale, x, y)
    SetTextFont(font)
    SetTextScale(scale, scale)
    SetTextColour(colour[1], colour[2], colour[3], 255)
    SetTextEntry("STRING")
    SetTextDropShadow(0, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextEdge(4, 0, 0, 0, 255)
    SetTextOutline()
    AddTextComponentString(content)
    DrawText(x, y)
end
