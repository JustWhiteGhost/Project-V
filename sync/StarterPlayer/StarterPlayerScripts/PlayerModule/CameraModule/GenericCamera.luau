local Players = game:GetService("Players")

local CameraState = require(script.Parent:WaitForChild("CameraState"))
local CameraUtils = require(script.Parent:WaitForChild("CameraUtils"))
local CameraInput = require(script.Parent:WaitForChild("CameraInput"))

local MIN_Y = math.rad(-80)
local MAX_Y = math.rad(80)
local INITIAL_CAMERA_ANGLE = CFrame.fromOrientation(math.rad(-15), 0, 0)
local TIME_BEFORE_AUTO_ROTATE = 2
local tweenAcceleration = math.rad(220)
local tweenSpeed = math.rad(0)
local tweenMaxSpeed = math.rad(250)

local GenericCamera = {}
GenericCamera.__index = GenericCamera
export type GenericCamera = typeof(setmetatable({} :: {
	_offsetController: any,
	_zoomController: any,
	_lastUpdate: number,
	_lastSubjectCFrame: CFrame?,
	_lastCameraTransform: CFrame?,
	_resetCameraAngle: boolean,
	_inFirstPerson: boolean,
	_currentLookVector: Vector3,
	_lastUserPanCamera: number,
}, {} :: typeof(GenericCamera)))


function GenericCamera.new(offsetController: any, zoomController: any)
	local self = setmetatable({}, GenericCamera)

	self._offsetController = offsetController
	self._zoomController = zoomController
	self._lastUpdate = tick()
	self._lastSubjectCFrame = nil
	self._lastCameraTransform = nil
	self._resetCameraAngle = true
	self._inFirstPerson = false
	self._currentLookVector = Vector3.new(0, 0, -1)
	self._lastUserPanCamera = tick()

	-- React to first person changes from ZoomController
	zoomController.firstPersonChanged.Event:Connect(function(isFirstPerson: boolean)
		if isFirstPerson then
			self:_enterFirstPerson()
		else
			self:_leaveFirstPerson()
		end
	end)

	return self
end

function GenericCamera:GetModuleName(): string
	return "GenericCamera"
end
function GenericCamera:Reset()
	self._resetCameraAngle = true
	self._lastCameraTransform = nil
end

function GenericCamera:_enterFirstPerson()
	self._inFirstPerson = true
	self._offsetController:SetOffset("firstPerson", Vector3.zero)
	CameraState.zoom.inFirstPerson = true
end

function GenericCamera:_leaveFirstPerson()
	self._inFirstPerson = false
	self._offsetController:ClearOffset("firstPerson")
	CameraState.zoom.inFirstPerson = false
end

function GenericCamera:_calculateNewLookVector(
	currentLook: Vector3,
	rotateInput: Vector2
): Vector3
	local currPitchAngle = math.asin(math.clamp(currentLook.Y, -1, 1))
	local yTheta = math.clamp(
		rotateInput.Y,
		-MAX_Y + currPitchAngle,
		-MIN_Y + currPitchAngle
	)
	local constrainedInput = Vector2.new(rotateInput.X, yTheta)
	local startCFrame = CFrame.new(Vector3.zero, currentLook)
	local newLookCFrame = CFrame.Angles(0, -constrainedInput.X, 0)
		* startCFrame
		* CFrame.Angles(-constrainedInput.Y, 0, 0)
	return newLookCFrame.LookVector
end

function GenericCamera:Update(dt: number)
	local now = tick()
	local camera = workspace.CurrentCamera
	if not camera then return end

	local player = Players.LocalPlayer
	if not player then return end

	-- Reset camera angle on respawn
	local overrideLookVector: Vector3? = nil
	if self._resetCameraAngle then
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart then
			overrideLookVector = (rootPart.CFrame * INITIAL_CAMERA_ANGLE).LookVector
		else
			overrideLookVector = INITIAL_CAMERA_ANGLE.LookVector
		end
		self._resetCameraAngle = false
	end

	local currentLook = overrideLookVector or self._currentLookVector

	-- Stale frame check
	if self._lastUpdate == nil or dt > 1 then
		self._lastCameraTransform = nil
	end

	local rotateInput = CameraInput.getRotation(dt)

	-- Track last user pan time
	if rotateInput ~= Vector2.zero then
		tweenSpeed = 0
		self._lastUserPanCamera = now
	end

	local userRecentlyPanned = now - self._lastUserPanCamera < TIME_BEFORE_AUTO_ROTATE

	-- Subject info from CameraState
	local subjectPosition = CameraState.subject.Position

	-- Apply offset to subject position
	local totalOffset = self._offsetController:GetTotalOffset()
	local offsetSubjectPosition = subjectPosition + totalOffset

	-- Auto rotate logic
	if not self._inFirstPerson and self._lastCameraTransform then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local cameraSubject = camera.CameraSubject
		local isInVehicle = cameraSubject and cameraSubject:IsA("VehicleSeat")
		local isOnSkateboard = cameraSubject and cameraSubject:IsA("SkateboardPlatform")
		local isClimbing = humanoid and humanoid:GetState() == Enum.HumanoidStateType.Climbing

		if not userRecentlyPanned then
			if (isInVehicle or isOnSkateboard) and self._lastSubjectCFrame and cameraSubject:IsA("BasePart") then
				local y = -CameraUtils.GetAngleBetweenXZVectors(
					self._lastSubjectCFrame.LookVector,
					cameraSubject.CFrame.LookVector
				)
				if CameraUtils.IsFinite(y) then
					rotateInput = rotateInput + Vector2.new(y, 0)
				end
				tweenSpeed = 0
			elseif isClimbing and humanoid and humanoid.Torso then
				local forwardVector = humanoid.Torso.CFrame.LookVector
				tweenSpeed = math.clamp(tweenSpeed + tweenAcceleration * dt, 0, tweenMaxSpeed)
				local percent = math.clamp(tweenSpeed * dt, 0, 1)
				local y = CameraUtils.GetAngleBetweenXZVectors(forwardVector, currentLook)
				if CameraUtils.IsFinite(y) and math.abs(y) > 0.0001 then
					rotateInput = rotateInput + Vector2.new(y * percent, 0)
				end
			end
		end
	end

	-- First person handling
	if self._inFirstPerson then
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart then
			local _, yaw, _ = rootPart.CFrame:ToEulerAnglesYXZ()
			local pitch = math.asin(math.clamp(currentLook.Y, -1, 1))
			currentLook = CFrame.fromEulerAnglesYXZ(pitch, yaw, 0).LookVector
		end

		local newLookVector = self:_calculateNewLookVector(currentLook, rotateInput)
		self._currentLookVector = newLookVector

		local focusPosition = offsetSubjectPosition
		local cameraPosition = focusPosition - newLookVector * 0.5

		CameraState.raw.cameraPosition = cameraPosition
		CameraState.raw.lookVector = newLookVector
	else
		local newLookVector = self:_calculateNewLookVector(currentLook, rotateInput)
		self._currentLookVector = newLookVector

		local zoom = self._zoomController:GetZoomRadius()
		local focusPosition = offsetSubjectPosition
		local cameraPosition = focusPosition - newLookVector * zoom

		self._lastCameraTransform = CFrame.lookAlong(cameraPosition, newLookVector)

		CameraState.raw.cameraPosition = cameraPosition
		CameraState.raw.lookVector = newLookVector
	end

	-- Track subject cframe for vehicle auto-rotate
	local cameraSubject = camera.CameraSubject
	if cameraSubject and cameraSubject:IsA("BasePart") then
		self._lastSubjectCFrame = cameraSubject.CFrame
	else
		self._lastSubjectCFrame = nil
	end

	self._lastUpdate = now
end

return GenericCamera
