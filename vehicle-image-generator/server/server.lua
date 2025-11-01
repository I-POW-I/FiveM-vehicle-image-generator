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

print('^2========================================^7')
print('^2POW Vehicle Image Generator^7')
print('^3Version:^7 1.0.0')
print('^3Command:^7 /vehui')
print('^3Stored Images:^7 ' .. CountTable(vehicleImages))
print('^2========================================^7')
