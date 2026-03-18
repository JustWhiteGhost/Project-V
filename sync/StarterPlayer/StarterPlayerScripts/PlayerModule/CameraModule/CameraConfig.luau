
local CameraConfig = {
    dampening = {
        enabled = true,
        positionFrequency = 5,
        rotationFrequency = 5,
    },
    shake = {
        enabled = true,
        maxAngleRandians = math.rad(5),
        maxOffset = 0.5,
        frequency = 25,
        decay = 1,
    },
    offset = {
        enabled = true,
        defaultOffset = Vector3.new(0, 0, 0),
        aimOffset = Vector3.new(1.3, 0, 0),
        mouseLockOffset = Vector3.new(1.75, 0, 0),
    },
    zoom = {
        defaultZoom = 12,
        minZoom = 5,
        maxZoom = 20,
        firstPersonThreshold = 1.5,
        sensitivity = 0.5,
    },
    crosshair = {
        enabled = true,
        image = "rbxassetid://1234567890", -- Placeholder asset ID for crosshair image
        size = UDim2.new(24, 0, 24, 0),
        color = Color3.fromRGB(255,255,255),
        hideInThirdPerson = false,
    },
    mouseLock = {
        boundKeys = {
            Enum.KeyCode.RightShift,
            Enum.KeyCode.LeftShift,
        },
        cursorImage = "rbxassetid://316279305", -- Placeholder asset ID for cursor image
    },
}

return CameraConfig
