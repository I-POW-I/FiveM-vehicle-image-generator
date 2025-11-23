Config = {}

-- ** Discord Webhook Configuration ** --
-- Leave empty - YOU input a webhook in the UI when it's opened
Config.DefaultWebhook = '' -- Set a default webhook here to pre-fill the UI input field

-- ** Vehicle Spawn Codes ** --
-- List your vehicle spawn codes here (labels will be auto-generated from the spawn code)
Config.VehicleSpawnCodes = {
    
    "gbargento7f", "gbbanshees", "gbcometcl", "gbcomets1t", "gbcomets2r",
    "gbirisz",
}

-- ** Camera Settings **--
Config.CameraSettings = {
    coords = vector3(-27.0600, -1095.9000, 27.6000), -- Where vehicles spawn
    heading = 143.4, -- Vehicle heading
    cameraOffset = vector3(-2.4, -8.2, 1.5), -- Camera position, front-left elevated
    cameraRotation = vector3(0.0, 0.0, -16.8), -- Camera angle, for front 3/4 view
    fov = 38.2 -- Field of view
}

-- ** Screenshot Settings ** --
Config.ScreenshotSettings = {
    encoding = 'webp',
    quality = 1.0 -- 0.0 to 1.0
}

-- ** Delay between captures (milliseconds) ** --
Config.CaptureDelay = 5000 -- 5 seconds between each vehicle (prevents Discord rate limiting)
