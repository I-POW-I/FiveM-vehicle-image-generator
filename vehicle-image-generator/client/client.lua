local isUIOpen = false
local isCapturing = false
local currentVehicle = nil
local captureData = {}

-- Open UI (Admin only via ACE permissions)
RegisterCommand('vehui', function()
    if not isUIOpen then
        isUIOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'open',
            vehicles = ConvertSpawnCodesToCategories(),
            webhook = Config.DefaultWebhook
        })
    end
end, false)  -- false = normal command, restricted via ACE

-- Register command suggestion
TriggerEvent('chat:addSuggestion', '/vehui', 'Open Vehicle Image Generator UI (Admin Only)')

-- Convert spawn codes to vehicle categories
function ConvertSpawnCodesToCategories()
    local categories = {}
    for i, vehicle in ipairs(Config.VehicleSpawnCodes) do
        if type(vehicle) == "string" then
            -- Simple string format: just spawn code
            local label = vehicle:sub(1,1):upper() .. vehicle:sub(2)
            table.insert(categories, {
                id = vehicle,
                label = label,
                model = vehicle
            })
        elseif type(vehicle) == "table" then
            -- Advanced format: {model = "adder", label = "Custom Name"}
            table.insert(categories, {
                id = vehicle.model,
                label = vehicle.label or vehicle.model,
                model = vehicle.model
            })
        end
    end
    return categories
end

-- NUI Callbacks
RegisterNUICallback('close', function(data, cb)
    isUIOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('testWebhook', function(data, cb)
    TriggerServerEvent('vehicle-image-generator:testWebhook', data.webhook)
    cb('ok')
end)

RegisterNUICallback('startCapture', function(data, cb)
    if not isCapturing then
        isCapturing = true
        captureData = {
            webhook = data.webhook,
            vehicles = data.vehicles,
            currentIndex = 1,
            total = #data.vehicles
        }
        
        -- Make player invisible
        local playerPed = PlayerPedId()
        SetEntityVisible(playerPed, false, false)
        SetEntityCollision(playerPed, false, false)
        
        -- Thread to keep HUD/radar hidden during capture
        Citizen.CreateThread(function()
            while isCapturing do
                DisplayRadar(false)
                DisplayHud(false)
                Citizen.Wait(0)
            end
        end)
        
        Citizen.CreateThread(function()
            CaptureNextVehicle()
        end)
    end
    cb('ok')
end)

RegisterNUICallback('stopCapture', function(data, cb)
    StopCapture()
    cb('ok')
end)

RegisterNUICallback('notify', function(data, cb)
    if data.type == 'success' then
        TriggerEvent('chat:addMessage', {
            color = {16, 185, 129},
            multiline = false,
            args = {"POW Vehicle Capture", data.message}
        })
    elseif data.type == 'error' then
        TriggerEvent('chat:addMessage', {
            color = {239, 68, 68},
            multiline = false,
            args = {"POW Vehicle Capture", data.message}
        })
    end
    cb('ok')
end)

-- Capture next vehicle
function CaptureNextVehicle()
    if not isCapturing or captureData.currentIndex > captureData.total then
        if isCapturing then
            -- All vehicles captured
            SendNUIMessage({
                action = 'captureComplete'
            })
            StopCapture()
        end
        return
    end
    
    local vehicle = captureData.vehicles[captureData.currentIndex]
    
    -- Update progress
    SendNUIMessage({
        action = 'updateProgress',
        current = captureData.currentIndex,
        total = captureData.total,
        vehicleName = vehicle.label
    })
    
    -- Spawn and capture vehicle
    SpawnAndCaptureVehicle(vehicle)
end

-- Spawn and capture vehicle
function SpawnAndCaptureVehicle(vehicleData)
    local playerPed = PlayerPedId()
    local coords = Config.CameraSettings.coords
    local heading = Config.CameraSettings.heading
    local modelHash = GetHashKey(vehicleData.model)
    
    -- Request model
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Citizen.Wait(100)
    end
    
    -- Delete previous vehicle if exists
    if currentVehicle and DoesEntityExist(currentVehicle) then
        DeleteEntity(currentVehicle)
    end
    
    -- Create vehicle
    currentVehicle = CreateVehicle(modelHash, coords.x, coords.y, coords.z, heading, false, false)
    
    -- Wait for vehicle to be created
    while not DoesEntityExist(currentVehicle) do
        Citizen.Wait(100)
    end
    
    -- Set vehicle properties
    SetEntityAsMissionEntity(currentVehicle, true, true)
    SetVehicleOnGroundProperly(currentVehicle)
    SetVehicleDoorsLocked(currentVehicle, 2)
    FreezeEntityPosition(currentVehicle, true)
    SetEntityAlpha(currentVehicle, 0, false)
    
    -- Fade in vehicle
    for alpha = 0, 255, 15 do
        SetEntityAlpha(currentVehicle, alpha, false)
        Citizen.Wait(10)
    end
    
    -- Hide HUD
    DisplayRadar(false)
    DisplayHud(false)
    
    -- Setup camera
    local camera = CreateCameraWithParams(
        "DEFAULT_SCRIPTED_CAMERA",
        coords.x + Config.CameraSettings.cameraOffset.x,
        coords.y + Config.CameraSettings.cameraOffset.y,
        coords.z + Config.CameraSettings.cameraOffset.z,
        Config.CameraSettings.cameraRotation.x,
        Config.CameraSettings.cameraRotation.y,
        Config.CameraSettings.cameraRotation.z,
        Config.CameraSettings.fov,
        true,
        2
    )
    
    SetCamActive(camera, true)
    RenderScriptCams(true, false, 0, true, true)
    PointCamAtEntity(camera, currentVehicle, 0.0, 0.0, 0.0, true)
    
    -- Wait for everything to settle
    Citizen.Wait(500)
    
    -- Take screenshot
    exports['screenshot-basic']:requestScreenshotUpload(captureData.webhook, 'files[]', {
        encoding = Config.ScreenshotSettings.encoding,
        quality = Config.ScreenshotSettings.quality
    }, function(data)
        local response = json.decode(data)
        
        if response and response.attachments and response.attachments[1] then
            local imageUrl = response.attachments[1].proxy_url or response.attachments[1].url
            
            -- Send to server to save
            TriggerServerEvent('vehicle-image-generator:saveImage', {
                vehicleId = vehicleData.id,
                vehicleLabel = vehicleData.label,
                vehicleModel = vehicleData.model,
                imageUrl = imageUrl
            })
            
            print('^2[POW Vehicle Capture]^7 Captured: ' .. vehicleData.label .. ' (' .. vehicleData.model .. ')')
        else
            print('^1[POW Vehicle Capture]^7 Failed to capture: ' .. vehicleData.label)
        end
        
        -- Cleanup
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(camera, false)
        
        -- Show HUD again
        DisplayRadar(true)
        DisplayHud(true)
        
        -- Move to next vehicle
        captureData.currentIndex = captureData.currentIndex + 1
        
        Citizen.Wait(Config.CaptureDelay)
        CaptureNextVehicle()
    end)
end

-- Stop capture
function StopCapture()
    isCapturing = false
    
    -- Cleanup current vehicle
    if currentVehicle and DoesEntityExist(currentVehicle) then
        DeleteEntity(currentVehicle)
        currentVehicle = nil
    end
    
    -- Reset camera
    RenderScriptCams(false, false, 0, true, true)
    
    -- Show HUD again
    DisplayRadar(true)
    DisplayHud(true)
    
    -- Make player visible again
    local playerPed = PlayerPedId()
    SetEntityVisible(playerPed, true, false)
    SetEntityCollision(playerPed, true, true)
    
    captureData = {}
    
    print('^3[POW Vehicle Capture]^7 Capture stopped')
end

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if currentVehicle and DoesEntityExist(currentVehicle) then
            DeleteEntity(currentVehicle)
        end
        RenderScriptCams(false, false, 0, true, true)
    end
end)

-- Event from server for notifications
RegisterNetEvent('vehicle-image-generator:notify')
AddEventHandler('vehicle-image-generator:notify', function(message, type)
    if type == 'success' then
        TriggerEvent('chat:addMessage', {
            color = {16, 185, 129},
            multiline = false,
            args = {"POW Vehicle Capture", message}
        })
    elseif type == 'error' then
        TriggerEvent('chat:addMessage', {
            color = {239, 68, 68},
            multiline = false,
            args = {"POW Vehicle Capture", message}
        })
    else
        TriggerEvent('chat:addMessage', {
            color = {59, 130, 246},
            multiline = false,
            args = {"POW Vehicle Capture", message}
        })
    end
end)
