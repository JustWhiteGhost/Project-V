local CameraState = {
    subject = {
        CFrame = CFrame.new(),
        Position = Vector3.new(),
    },
    raw = {
        cameraPosition = Vector3.new(),
        lookVector = Vector3.new(),
    },
    dampened = {
        cameraPosition = Vector3.new(),
        lookVector = Vector3.new(),
    },
    shake = {
        trauma = 0,
        offset = Vector3.new(),
        rotation = Vector3.new()
    },
    offset = {
        total = Vector3.new(),
    },
    zoom = {
        currentZoom = 12,
        target = 12,
        inFirstPerson = false,
    },
    mouseLock = {
        isLocked = false,
        offset = Vector3.new(),
    },
}

return CameraState
