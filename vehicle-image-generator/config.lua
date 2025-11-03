Config = {}

-- ** Discord Webhook Configuration ** --
-- Leave empty - YOU input a webhook in the UI when it's opened
Config.DefaultWebhook = '' -- Set a default webhook here to pre-fill the UI input field

-- ** Vehicle Spawn Codes ** --
-- List your vehicle model names here (labels come from Config.ImportedVehicles below if defined)
Config.VehicleSpawnCodes = {
    
    "gbargento7f", "gbbanshees", "gbcometcl", "gbcomets1t", "gbcomets2r",
    "gbirisz",
}

-- ** Custom Labels for Imported Vehicles **
--Config.ImportedVehicles = {

--}

-- ** Camera Settings **--
Config.CameraSettings = {
    coords = vector3(-772.2191, 768.9974, 213.1987), -- Where vehicles spawn
    heading = 0.0, -- Vehicle heading
    cameraOffset = vector3(-3.0, 8.0, 1.4), -- Camera position, front-left elevated
    cameraRotation = vector3(-15.0, 0.0, 215.0), -- Camera angle, for front 3/4 view
    fov = 37.0 -- Field of view
}

-- ** Screenshot Settings ** --
Config.ScreenshotSettings = {
    encoding = 'jpg',
    quality = 0.95 -- 0.0 to 1.0
}

-- ** Delay between captures (milliseconds) ** --
Config.CaptureDelay = 5000 -- 5 seconds between each vehicle (prevents Discord rate limiting)

