local isUIOpen = false
local isCapturing = false
local currentVehicle = nil
local captureData = {}
local previewVehicle = nil
local previewCamera = nil
local isPreviewMode = false

-- Open UI (Admin only via ACE permissions)
RegisterCommand('vehui', function()
    if not isUIOpen then
        isUIOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'open',
            vehicles = ConvertSpawnCodesToCategories(),
            webhook = Config.DefaultWebhook,
            cameraSettings = {
                coords = {
                    x = Config.CameraSettings.coords.x,
                    y = Config.CameraSettings.coords.y,
                    z = Config.CameraSettings.coords.z
                },
                heading = Config.CameraSettings.heading,
                cameraOffset = {
                    x = Config.CameraSettings.cameraOffset.x,
                    y = Config.CameraSettings.cameraOffset.y,
                    z = Config.CameraSettings.cameraOffset.z
                },
                cameraRotation = {
                    x = Config.CameraSettings.cameraRotation.x,
                    y = Config.CameraSettings.cameraRotation.y,
                    z = Config.CameraSettings.cameraRotation.z
                },
                fov = Config.CameraSettings.fov
            }
        })
    end
end, false)  -- false = normal command, restricted via ACE

-- Register command suggestion
TriggerEvent('chat:addSuggestion', '/vehui', 'Open Vehicle Image Generator UI (Admin Only)')

-- Convert spawn codes to vehicle categories
function ConvertSpawnCodesToCategories()
    local categories = {}
    
    if not Config or not Config.VehicleSpawnCodes then
        print("^1[vehicle-image-generator]^7 ERROR: Config.VehicleSpawnCodes is not defined!")
        return categories
    end
    
    print("^2[vehicle-image-generator]^7 Loading " .. #Config.VehicleSpawnCodes .. " vehicles from config")
    
    -- Convert spawn codes to category entries with auto-generated labels
    for i, spawnCode in ipairs(Config.VehicleSpawnCodes) do
        local label = spawnCode:sub(1,1):upper() .. spawnCode:sub(2) -- Capitalize first letter
        table.insert(categories, {
            id = spawnCode,
            label = label,
            model = spawnCode
        })
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
            total = #data.vehicles,
            cameraSettings = data.cameraSettings or nil -- Use custom settings if provided
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

RegisterNUICallback('startPreview', function(data, cb)
    if not isPreviewMode then
        StartPreviewMode(data.cameraSettings)
    end
    cb('ok')
end)

RegisterNUICallback('updatePreview', function(data, cb)
    if isPreviewMode then
        UpdatePreviewCamera(data.cameraSettings)
    end
    cb('ok')
end)

RegisterNUICallback('stopPreview', function(data, cb)
    StopPreviewMode()
    cb('ok')
end)

RegisterNUICallback('saveConfig', function(data, cb)
    TriggerServerEvent('vehicle-image-generator:saveConfig', data.cameraSettings)
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
    
    -- Use custom camera settings if provided, otherwise use config
    local camSettings = captureData.cameraSettings or Config.CameraSettings
    local coords = vector3(camSettings.coords.x, camSettings.coords.y, camSettings.coords.z)
    local heading = camSettings.heading
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
    
    -- Setup camera with custom or config settings
    local camera = CreateCameraWithParams(
        "DEFAULT_SCRIPTED_CAMERA",
        coords.x + camSettings.cameraOffset.x,
        coords.y + camSettings.cameraOffset.y,
        coords.z + camSettings.cameraOffset.z,
        camSettings.cameraRotation.x,
        camSettings.cameraRotation.y,
        camSettings.cameraRotation.z,
        camSettings.fov,
        true,
        2
    )
    
    SetCamActive(camera, true)
    RenderScriptCams(true, false, 0, true, true)
    -- Don't use PointCamAtEntity - let rotation values control the camera angle
    
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
        if previewVehicle and DoesEntityExist(previewVehicle) then
            DeleteEntity(previewVehicle)
        end
        if previewCamera then
            DestroyCam(previewCamera, false)
        end
        RenderScriptCams(false, false, 0, true, true)
        DisplayRadar(true)
        DisplayHud(true)
        local playerPed = PlayerPedId()
        SetEntityVisible(playerPed, true, false)
        SetEntityCollision(playerPed, true, true)
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

-- ========================================
-- PREVIEW MODE FUNCTIONS
-- ========================================

-- Start preview mode with a test vehicle
function StartPreviewMode(cameraSettings)
    isPreviewMode = true
    
    local playerPed = PlayerPedId()
    SetEntityVisible(playerPed, false, false)
    
    local coords = vector3(cameraSettings.coords.x, cameraSettings.coords.y, cameraSettings.coords.z)
    local heading = cameraSettings.heading
    local modelHash = GetHashKey('adder') -- Use adder as preview vehicle
    
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Citizen.Wait(100)
    end
    
    -- Delete old preview vehicle if exists
    if previewVehicle and DoesEntityExist(previewVehicle) then
        DeleteEntity(previewVehicle)
    end
    
    -- Create preview vehicle
    previewVehicle = CreateVehicle(modelHash, coords.x, coords.y, coords.z, heading, false, false)
    
    while not DoesEntityExist(previewVehicle) do
        Citizen.Wait(100)
    end
    
    SetEntityAsMissionEntity(previewVehicle, true, true)
    SetVehicleOnGroundProperly(previewVehicle)
    FreezeEntityPosition(previewVehicle, true)
    
    -- Setup camera
    UpdatePreviewCamera(cameraSettings)
    
    -- Hide HUD
    DisplayRadar(false)
    DisplayHud(false)
    
    print('^2[POW Vehicle Capture]^7 Preview mode started')
end

-- Update preview camera with new settings
function UpdatePreviewCamera(cameraSettings)
    if not isPreviewMode then return end
    
    local coords = vector3(cameraSettings.coords.x, cameraSettings.coords.y, cameraSettings.coords.z)
    
    -- Destroy old camera
    if previewCamera then
        DestroyCam(previewCamera, false)
    end
    
    -- Create new camera with updated settings
    previewCamera = CreateCameraWithParams(
        "DEFAULT_SCRIPTED_CAMERA",
        coords.x + cameraSettings.cameraOffset.x,
        coords.y + cameraSettings.cameraOffset.y,
        coords.z + cameraSettings.cameraOffset.z,
        cameraSettings.cameraRotation.x,
        cameraSettings.cameraRotation.y,
        cameraSettings.cameraRotation.z,
        cameraSettings.fov,
        true,
        2
    )
    
    SetCamActive(previewCamera, true)
    RenderScriptCams(true, false, 0, true, true)
    
    if previewVehicle and DoesEntityExist(previewVehicle) then
        -- Update vehicle position if coords changed
        SetEntityCoords(previewVehicle, coords.x, coords.y, coords.z, false, false, false, true)
        SetEntityHeading(previewVehicle, cameraSettings.heading)
        SetVehicleOnGroundProperly(previewVehicle)
        -- Don't use PointCamAtEntity - let rotation values control the camera angle
    end
end

-- Stop preview mode
function StopPreviewMode()
    isPreviewMode = false
    
    -- Cleanup preview vehicle
    if previewVehicle and DoesEntityExist(previewVehicle) then
        DeleteEntity(previewVehicle)
        previewVehicle = nil
    end
    
    -- Cleanup camera
    if previewCamera then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(previewCamera, false)
        previewCamera = nil
    end
    
    -- Show HUD
    DisplayRadar(true)
    DisplayHud(true)
    
    -- Make player visible
    local playerPed = PlayerPedId()
    SetEntityVisible(playerPed, true, false)
    
    print('^3[POW Vehicle Capture]^7 Preview mode stopped')
end

