local CameraConfig = {
	dampening = {
		enabled = true,
		positionFrequency = 4,
		rotationFrequency = 4,
	},
	shake = {
		enabled = true,
		maxTrauma = 3,
		maxAngleRandians = math.rad(12),
		maxOffset = 1.4,
		frequency = 1,
		decay = 5,
		explosionPushMax = 1.25,
		explosionPushDecay = 12,
	},
	offset = {
		enabled = true,
		defaultOffset = Vector3.new(0, 0, 0),
		mouseLockOffset = Vector3.new(1, 0.6, 1.1),
		smoothTransitionFreq = 6,
	},
	zoom = {
		defaultZoom = 12,
		minZoom = 3,
		maxZoom = 20,
		firstPersonThreshold = 1.5,
		sensitivity = 0.5,
	},
	input = {
		mouseSensitivity = 1,
		zoomSensitivity = 0.001,
	},
	crosshair = {
		enabled = true,
		image = "rbxassetid://1234567890", -- Placeholder asset ID for crosshair image
		size = UDim2.new(24, 0, 24, 0),
		color = Color3.fromRGB(255, 255, 255),
		hideInThirdPerson = false,

		aimImage = "rbxassetid://0987654321", -- Placeholder asset ID for aim crosshair image
		aimSize = UDim2.fromOffset(12, 12),
	},
	mouseLock = {
		boundKeys = {
			Enum.KeyCode.RightShift,
			Enum.KeyCode.LeftControl,
		},
		cursorImage = "rbxassetid://316279305", -- Placeholder asset ID for cursor image
	},
	headTracking = {
		enabled = true,
		headHorizontalFactor = 1,
		headVerticalFactor = 0.6,
		bodyHorizontalFactor = 0.5,
		bodyVerticalFactor = 0.4,
		updateSpeed = 0.25,
	},
	aim = {
		enabled = true,
		offset = Vector3.new(0, 0, -1.5),
		fov = 55,
		transitionSpeed = 10,
	},
}

return CameraConfig
