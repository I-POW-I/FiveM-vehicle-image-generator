-- Storage for vehicle images
local vehicleImages = {}
local imageSaveFile = 'vehicle-images.json'

-- Load saved images on resource start
Citizen.CreateThread(function()
    local data = LoadResourceFile(GetCurrentResourceName(), imageSaveFile)
    if data then
        vehicleImages = json.decode(data) or {}
        print('^2[POW Vehicle Image Generator]^7 Loaded ' .. CountTable(vehicleImages) .. ' vehicle images')
    else
        print('^3[POW Vehicle Image Generator]^7 No saved images found, starting fresh')
    end
end)

-- Count table entries
function CountTable(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

-- Test webhook
RegisterNetEvent('vehicle-image-generator:testWebhook')
AddEventHandler('vehicle-image-generator:testWebhook', function(webhook)
    local src = source
    
    PerformHttpRequest(webhook, function(statusCode, text, headers)
        if statusCode == 200 or statusCode == 204 then
            TriggerClientEvent('vehicle-image-generator:notify', src, 'Webhook test successful!', 'success')
        else
            TriggerClientEvent('vehicle-image-generator:notify', src, 'Webhook test failed! Status: ' .. statusCode, 'error')
        end
    end, 'POST', json.encode({
        username = "POW Vehicle Image Generator",
        content = "✅ Webhook connection test successful!"
    }), {
        ['Content-Type'] = 'application/json'
    })
end)

-- Save captured image
RegisterNetEvent('vehicle-image-generator:saveImage')
AddEventHandler('vehicle-image-generator:saveImage', function(data)
    local src = source
    
    if not data or not data.vehicleId or not data.imageUrl then
        return
    end
    
    -- Store image data
    vehicleImages[data.vehicleModel] = {
        id = data.vehicleId,
        label = data.vehicleLabel,
        model = data.vehicleModel,
        imageUrl = data.imageUrl,
        timestamp = os.time()
    }
    
    -- Save to file
    SaveResourceFile(GetCurrentResourceName(), imageSaveFile, json.encode(vehicleImages, {indent = true}), -1)

    print('^2[POW Vehicle Image Generator]^7 Saved image for: ' .. data.vehicleLabel .. ' (Total: ' .. CountTable(vehicleImages) .. ')')
end)

-- Export to get vehicle image
exports('GetVehicleImage', function(model)
    if vehicleImages[model] then
        return vehicleImages[model].imageUrl
    end
    return nil
end)

-- Export to get all vehicle images
exports('GetAllVehicleImages', function()
    return vehicleImages
end)

-- Server command to clear all images
RegisterCommand('clearimages', function(source, args, rawCommand)
    local src = source
    
    if src == 0 then
        vehicleImages = {}
        SaveResourceFile(GetCurrentResourceName(), imageSaveFile, json.encode(vehicleImages), -1)
        print('^2[POW Vehicle Image Generator]^7 All images cleared')
    else
        TriggerClientEvent('vehicle-image-generator:notify', src, 
            'This command can only be run from the server console', 'error')
    end
end, false)

-- Save camera settings to config.lua
RegisterNetEvent('vehicle-image-generator:saveConfig')
AddEventHandler('vehicle-image-generator:saveConfig', function(cameraSettings)
    local src = source
    
    if not cameraSettings then
        TriggerClientEvent('vehicle-image-generator:notify', src, 'Invalid camera settings', 'error')
        return
    end
    
    -- Read current config file
    local configPath = 'config.lua'
    local configData = LoadResourceFile(GetCurrentResourceName(), configPath)
    
    if not configData then
        TriggerClientEvent('vehicle-image-generator:notify', src, 'Failed to read config.lua', 'error')
        return
    end
    
    -- Build new camera settings string
    local newCameraSettings = string.format([[Config.CameraSettings = {
    coords = vector3(%.4f, %.4f, %.4f), -- Where vehicles spawn
    heading = %.1f, -- Vehicle heading
    cameraOffset = vector3(%.1f, %.1f, %.1f), -- Camera position, front-left elevated
    cameraRotation = vector3(%.1f, %.1f, %.1f), -- Camera angle, for front 3/4 view
    fov = %.1f -- Field of view
}]], 
        cameraSettings.coords.x, cameraSettings.coords.y, cameraSettings.coords.z,
        cameraSettings.heading,
        cameraSettings.cameraOffset.x, cameraSettings.cameraOffset.y, cameraSettings.cameraOffset.z,
        cameraSettings.cameraRotation.x, cameraSettings.cameraRotation.y, cameraSettings.cameraRotation.z,
        cameraSettings.fov
    )
    
    -- Replace the camera settings section in config (matches multi-line with nested braces)
    local pattern = "Config%.CameraSettings%s*=%s*%b{}"
    local updatedConfig = configData:gsub(pattern, newCameraSettings)
    
    -- Save updated config
    local success = SaveResourceFile(GetCurrentResourceName(), configPath, updatedConfig, -1)
    
    if success then
        -- Update runtime config
        Config.CameraSettings.coords = vector3(cameraSettings.coords.x, cameraSettings.coords.y, cameraSettings.coords.z)
        Config.CameraSettings.heading = cameraSettings.heading
        Config.CameraSettings.cameraOffset = vector3(cameraSettings.cameraOffset.x, cameraSettings.cameraOffset.y, cameraSettings.cameraOffset.z)
        Config.CameraSettings.cameraRotation = vector3(cameraSettings.cameraRotation.x, cameraSettings.cameraRotation.y, cameraSettings.cameraRotation.z)
        Config.CameraSettings.fov = cameraSettings.fov
        
        TriggerClientEvent('vehicle-image-generator:notify', src, 'Camera settings saved to config.lua!', 'success')
        print('^2[POW Vehicle Image Generator]^7 Camera settings saved by player ' .. src)
    else
        TriggerClientEvent('vehicle-image-generator:notify', src, 'Failed to save config.lua', 'error')
    end
end)

print('^2========================================^7')
print('^2POW Vehicle Image Generator^7')
print('^3Version:^7 1.0.0')
print('^3Command:^7 /vehui')
print('^3Stored Images:^7 ' .. CountTable(vehicleImages))
print('^2========================================^7')
