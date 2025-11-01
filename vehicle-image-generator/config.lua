Config = {}

-- ** Discord Webhook Configuration ** --
-- Leave empty - YOU input a webhook in the UI when it's opened
Config.DefaultWebhook = '' -- Set a default webhook here to pre-fill the UI input field

-- ** Vehicle Spawn Codes ** --
-- Just add your spawn codes here, one per line!
Config.VehicleSpawnCodes = {
    "adder",
    "t20",
    "zentorno",
    -- etc...
}

-- ** ADVANCED: If you want custom labels, use this instead:
-- Config.VehicleSpawnCodes = {
--     {model = "adder", label = "Truffade Adder"},
--     {model = "t20", label = "Progen T20"},
--     -- etc.
-- }

-- ** Camera Settings **--
Config.CameraSettings = {
    coords = vector3(-75.5465, -818.4789, 326.1751), -- Where vehicles spawn
    heading = 0.0, -- Vehicle heading
    cameraOffset = vector3(-3.0, 8.0, 1.4), -- Camera position, front-left elevated
    cameraRotation = vector3(-15.0, 0.0, 215.0), -- Camera angle, for front 3/4 view
    fov = 32.5 -- Field of view
}

-- ** Screenshot Settings ** --
Config.ScreenshotSettings = {
    encoding = 'jpg',
    quality = 0.95 -- 0.0 to 1.0
}

-- ** Delay between captures (milliseconds) ** --
Config.CaptureDelay = 5000 -- 5 seconds between each vehicle (prevents Discord rate limiting)
