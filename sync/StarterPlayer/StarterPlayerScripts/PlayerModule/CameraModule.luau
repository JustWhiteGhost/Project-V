--!strict
-- CameraModule
-- Orchestrates all camera systems and exposes the public developer API.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local workspace = game:GetService("Workspace")

local CameraModule = {}
CameraModule.__index = CameraModule

local CommonUtils = script.Parent:WaitForChild("CommonUtils")
local ConnectionUtil = require(CommonUtils:WaitForChild("ConnectionUtil"))
local FlagUtil = require(CommonUtils:WaitForChild("FlagUtil"))

-- Core utils
local CameraUtils = require(script:WaitForChild("CameraUtils"))
local CameraInput = require(script:WaitForChild("CameraInput"))
local CameraUI = require(script:WaitForChild("CameraUI"))
local CameraToggleStateController = require(script:WaitForChild("CameraToggleStateController"))

-- Data
local CameraConfig = require(script:WaitForChild("CameraConfig"))
local CameraState = require(script:WaitForChild("CameraState"))

-- Systems
local DampeningController = require(script:WaitForChild("DampeningController"))
local ShakeController = require(script:WaitForChild("ShakeController"))
local OffsetController = require(script:WaitForChild("OffsetController"))
local ZoomController = require(script:WaitForChild("ZoomController"))
local MouseLockController = require(script:WaitForChild("MouseLockController"))
local CrosshairController = require(script:WaitForChild("CrosshairController"))
local GenericCamera = require(script:WaitForChild("GenericCamera"))

-- Occlusion
local Invisicam = require(script:WaitForChild("Invisicam"))
local Poppercam = require(script:WaitForChild("Poppercam"))

-- Transparency
local TransparencyController = require(script:WaitForChild("TransparencyController"))

local instantiatedOcclusionModules = {}

local FFlagUserPlayerConnectionMemoryLeak = FlagUtil.getUserFlag("UserPlayerConnectionMemoryLeak")

if not Players.LocalPlayer then
	return {}
end
assert(Players.LocalPlayer, "Strict typing check")

do
	local PlayerScripts: PlayerScripts = Players.LocalPlayer:WaitForChild("PlayerScripts") :: PlayerScripts
	PlayerScripts:RegisterTouchCameraMovementMode(Enum.TouchCameraMovementMode.Default)
	PlayerScripts:RegisterTouchCameraMovementMode(Enum.TouchCameraMovementMode.Follow)
	PlayerScripts:RegisterTouchCameraMovementMode(Enum.TouchCameraMovementMode.Classic)
	PlayerScripts:RegisterComputerCameraMovementMode(Enum.ComputerCameraMovementMode.Default)
end

type Generic = any
type GenericOptional = any?

type CameraModuleClass = {
	__index: CameraModuleClass,
	new: () -> CameraModule,

	ActivateOcclusionModule: (self: CameraModule, occlusionMode: Enum.DevCameraOcclusionMode) -> (),
	OnCameraSubjectChanged: (self: CameraModule) -> (),
	OnCharacterAdded: (self: CameraModule, character: Model, player: Player) -> (),
	OnCharacterRemoving: (self: CameraModule, character: Model, player: Player) -> (),
	OnCurrentCameraChanged: (self: CameraModule) -> (),
	OnPlayerAdded: (self: CameraModule, player: Player) -> (),
	OnPlayerRemoving: (self: CameraModule, player: Player) -> (),
	Update: (self: CameraModule, dt: number) -> (),
	_updateSubject: (self: CameraModule) -> (),

	-- Public API
	AddCameraShake: (self: CameraModule, trauma: number) -> (),
	AddNamedShake: (self: CameraModule, tag: string, trauma: number, decayRate: number?) -> (),
	CancelShake: (self: CameraModule, tag: string) -> (),
	SetCameraOffset: (self: CameraModule, name: string, offset: Vector3) -> (),
	ClearCameraOffset: (self: CameraModule, name: string) -> (),
	SetDampening: (self: CameraModule, posHz: number, rotHz: number) -> (),
	SetDampeningEnabled: (self: CameraModule, enabled: boolean) -> (),
	SetZoomBounds: (self: CameraModule, min: number, max: number) -> (),
	SetZoom: (self: CameraModule, studs: number) -> (),
	SetMouseLocked: (self: CameraModule, locked: boolean) -> (),
	IsMouseLocked: (self: CameraModule) -> boolean,
	SetCrosshairEnabled: (self: CameraModule, enabled: boolean) -> (),
	SetCrosshairImage: (self: CameraModule, assetId: string) -> (),
	SetCrosshairColor: (self: CameraModule, color: Color3) -> (),
	SetCrosshairSize: (self: CameraModule, size: UDim2) -> (),
}

export type CameraModule = typeof(setmetatable(
	{} :: {
		activeOcclusionModule: GenericOptional,
		activeTransparencyController: Generic,
		cameraSubjectChangedConn: RBXScriptConnection?,
		cameraTypeChangedConn: RBXScriptConnection?,
		connectionUtil: ConnectionUtil.ConnectionUtil?,
		occlusionMode: Enum.DevCameraOcclusionMode?,

		-- Systems
		genericCamera: any,
		dampeningController: any,
		shakeController: any,
		offsetController: any,
		zoomController: any,
		mouseLockController: any,
		crosshairController: any,
	},
	{} :: CameraModuleClass
))

function CameraModule.new()
	local self: CameraModule = setmetatable({}, CameraModule)
	self.mouseLockController = MouseLockController.new()
	print("Initiated:", self.mouseLockController)
	local ok, result = pcall(function()
		return MouseLockController.new()
	end)
	print("pcall result:", ok, result)
	if ok then
		self.mouseLockController = result
		print("methods:", self.mouseLockController:IsMouseLocked())
	end
	self.activeOcclusionModule = nil
	self.cameraSubjectChangedConn = nil
	self.cameraTypeChangedConn = nil
	self.occlusionMode = nil

	-- 1. Transparency
	self.activeTransparencyController = TransparencyController.new()
	self.activeTransparencyController:Enable(true)

	-- 2. Connection util
	self.connectionUtil = if FFlagUserPlayerConnectionMemoryLeak then ConnectionUtil.new() else nil

	-- 3. Initialize systems in dependency order
	self.zoomController = ZoomController.new()
	self.offsetController = OffsetController.new()
	self.dampeningController = DampeningController.new()
	self.shakeController = ShakeController.new()
	self.crosshairController = CrosshairController.new()
	print("zoomController instance:", self.zoomController)
	print("zoomController.firstPersonChanged:", self.zoomController.firstPersonChanged)
	self.genericCamera = GenericCamera.new(self.offsetController, self.zoomController)

	-- 4. Enable camera input
	CameraInput.setInputEnabled(true)

	-- 5. React to mouse lock toggle
	self.mouseLockController:GetBindableToggleEvent():Connect(function(isLocked: boolean)
		self.offsetController:Update(isLocked)
	end)

	-- 6. Player connections
	for _, player in pairs(Players:GetPlayers()) do
		self:OnPlayerAdded(player)
	end

	Players.PlayerAdded:Connect(function(player)
		self:OnPlayerAdded(player)
	end)

	if FFlagUserPlayerConnectionMemoryLeak then
		Players.PlayerRemoving:Connect(function(player)
			self:OnPlayerRemoving(player)
		end)
	end

	-- 7. Occlusion
	self:ActivateOcclusionModule(Players.LocalPlayer.DevCameraOcclusionMode)

	Players.LocalPlayer:GetPropertyChangedSignal("DevCameraOcclusionMode"):Connect(function()
		self:ActivateOcclusionModule(Players.LocalPlayer.DevCameraOcclusionMode)
	end)

	-- 8. Initial camera setup
	self:OnCurrentCameraChanged()

	-- 9. Bind render step
	RunService:BindToRenderStep("CameraSystemUpdate", Enum.RenderPriority.Camera.Value, function(dt)
		self:Update(dt)
	end)

	-- 10. Watch for camera changes
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		self:OnCurrentCameraChanged()
	end)

	return self
end

-- Private: update CameraState.subject from current camera subject
function CameraModule:_updateSubject()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local subject = camera.CameraSubject
	if not subject then
		return
	end

	local position: Vector3
	local cframe: CFrame

	if subject:IsA("Humanoid") then
		local rootPart = subject.RootPart
		if rootPart then
			position = rootPart.Position + Vector3.new(0, 1.5, 0)
			cframe = rootPart.CFrame
		end
	elseif subject:IsA("BasePart") then
		position = subject.Position
		cframe = subject.CFrame
	elseif subject:IsA("Model") then
		if subject.PrimaryPart then
			position = subject.PrimaryPart.Position
			cframe = subject.PrimaryPart.CFrame
		end
	end

	if position then
		CameraState.subject.Position = position
	end
	if cframe then
		CameraState.subject.CFrame = cframe
	end
end

function CameraModule:ActivateOcclusionModule(occlusionMode: Enum.DevCameraOcclusionMode)
	local newModuleCreator
	if occlusionMode == Enum.DevCameraOcclusionMode.Zoom then
		newModuleCreator = Poppercam
	elseif occlusionMode == Enum.DevCameraOcclusionMode.Invisicam then
		newModuleCreator = Invisicam
	else
		warn("CameraScript ActivateOcclusionModule called with unsupported mode")
		return
	end

	self.occlusionMode = occlusionMode

	if self.activeOcclusionModule and self.activeOcclusionModule:GetOcclusionMode() == occlusionMode then
		if not self.activeOcclusionModule:GetEnabled() then
			self.activeOcclusionModule:Enable(true)
		end
		return
	end

	local prevOcclusionModule = self.activeOcclusionModule
	self.activeOcclusionModule = instantiatedOcclusionModules[newModuleCreator]

	if not self.activeOcclusionModule then
		self.activeOcclusionModule = newModuleCreator.new()
		if self.activeOcclusionModule then
			instantiatedOcclusionModules[newModuleCreator] = self.activeOcclusionModule
		end
	end

	if self.activeOcclusionModule then
		if self.activeOcclusionModule:GetOcclusionMode() ~= occlusionMode then
			warn("CameraScript ActivateOcclusionModule mismatch")
		end

		if prevOcclusionModule then
			if prevOcclusionModule ~= self.activeOcclusionModule then
				prevOcclusionModule:Enable(false)
			else
				warn("CameraScript ActivateOcclusionModule failure to detect already running correct module")
			end
		end

		if occlusionMode == Enum.DevCameraOcclusionMode.Invisicam then
			if Players.LocalPlayer.Character then
				self.activeOcclusionModule:CharacterAdded(Players.LocalPlayer.Character, Players.LocalPlayer)
			end
		else
			for _, player in pairs(Players:GetPlayers()) do
				if player and player.Character then
					self.activeOcclusionModule:CharacterAdded(player.Character, player)
				end
			end
			self.activeOcclusionModule:OnCameraSubjectChanged((workspace.CurrentCamera :: Camera).CameraSubject)
		end

		self.activeOcclusionModule:Enable(true)
	end
end

function CameraModule:OnCameraSubjectChanged()
	local camera = workspace.CurrentCamera
	local cameraSubject = if camera then camera.CameraSubject else nil

	-- Update subject state first
	self:_updateSubject()

	if self.activeTransparencyController then
		self.activeTransparencyController:SetSubject(cameraSubject)
	end

	if self.activeOcclusionModule then
		self.activeOcclusionModule:OnCameraSubjectChanged(cameraSubject)
	end
end

function CameraModule:OnCurrentCameraChanged()
	local currentCamera = workspace.CurrentCamera
	if not currentCamera then
		return
	end

	if self.cameraSubjectChangedConn then
		self.cameraSubjectChangedConn:Disconnect()
	end

	if self.cameraTypeChangedConn then
		self.cameraTypeChangedConn:Disconnect()
	end

	self.cameraSubjectChangedConn = currentCamera:GetPropertyChangedSignal("CameraSubject"):Connect(function()
		self:OnCameraSubjectChanged()
	end)

	-- Reset camera on new camera instance
	if self.genericCamera then
		self.genericCamera:Reset()
		self.dampeningController:Reset()
	end

	self:OnCameraSubjectChanged()
end

function CameraModule:Update(dt: number)
	-- 1. Update subject
	self:_updateSubject()

	-- 2. Update offset based on mouse lock state
	local isMouseLocked = self.mouseLockController:IsMouseLocked()
	self.offsetController:Update(isMouseLocked)

	-- 3. Step generic camera (writes to CameraState.raw)
	self.genericCamera:Update(dt)

	-- 4. Step dampening (writes to CameraState.dampened)
	self.dampeningController:Update(dt)

	-- 5. Step shake (writes to CameraState.shake)
	self.shakeController:Update(dt)

	-- 6. Assemble final CFrame
	local pos = CameraState.dampened.cameraPosition + CameraState.shake.offset
	local look = CameraUtils.ApplyRotationToVector(CameraState.dampened.lookVector, CameraState.shake.rotation)

	local worldOffset = CFrame.lookAlong(
    CameraState.subject.Position, 
    CameraState.dampened.lookVector
):VectorToWorldSpace(CameraState.offset.total)

	local finalCFrame = CFrame.lookAlong(pos, look)
	local finalFocus = CFrame.new(CameraState.subject.Position + worldOffset)

	-- 7. Occlusion
	if self.activeOcclusionModule then
		finalCFrame, finalFocus = self.activeOcclusionModule:Update(dt, finalCFrame, finalFocus, self.zoomController)
	end

	-- 8. Apply to camera
	local currentCamera = workspace.CurrentCamera :: Camera
	currentCamera.CFrame = finalCFrame
	currentCamera.Focus = finalFocus

	-- 9. Transparency
	if self.activeTransparencyController then
		self.activeTransparencyController:Update(dt)
	end

	-- 10. Crosshair
	local isFirstPerson = CameraState.zoom.inFirstPerson
	self.crosshairController:Update(dt, isMouseLocked, isFirstPerson)

	-- 11. Reset input for next frame
	if CameraInput.getInputEnabled() then
		CameraInput.resetInputForFrameEnd()
	end
end

function CameraModule:OnCharacterAdded(char: Model, player: Player)
	if self.activeOcclusionModule then
		self.activeOcclusionModule:CharacterAdded(char, player)
	end
end

function CameraModule:OnCharacterRemoving(char: Model, player: Player)
	if self.activeOcclusionModule then
		self.activeOcclusionModule:CharacterRemoving(char, player)
	end
end

function CameraModule:OnPlayerAdded(player: Player)
	if FFlagUserPlayerConnectionMemoryLeak then
		if self.connectionUtil then
			self.connectionUtil:trackConnection(
				`{player.UserId}CharacterAdded`,
				player.CharacterAdded:Connect(function(char)
					self:OnCharacterAdded(char, player)
				end)
			)
			self.connectionUtil:trackConnection(
				`{player.UserId}CharacterRemoving`,
				player.CharacterRemoving:Connect(function(char)
					self:OnCharacterRemoving(char, player)
				end)
			)
		end
	else
		player.CharacterAdded:Connect(function(char)
			self:OnCharacterAdded(char, player)
		end)
		player.CharacterRemoving:Connect(function(char)
			self:OnCharacterRemoving(char, player)
		end)
	end
end

function CameraModule:OnPlayerRemoving(player: Player)
	if self.connectionUtil then
		self.connectionUtil:disconnect(`{player.UserId}CharacterAdded`)
		self.connectionUtil:disconnect(`{player.UserId}CharacterRemoving`)
	end
end

-- Public API

function CameraModule:AddCameraShake(trauma: number)
	self.shakeController:AddTrauma(trauma)
end

function CameraModule:AddNamedShake(tag: string, trauma: number, decayRate: number?)
	self.shakeController:AddNamedShake(tag, trauma, decayRate)
end

function CameraModule:CancelShake(tag: string)
	self.shakeController:CancelShake(tag)
end

function CameraModule:SetCameraOffset(name: string, offset: Vector3)
	self.offsetController:SetOffset(name, offset)
end

function CameraModule:ClearCameraOffset(name: string)
	self.offsetController:ClearOffset(name)
end

function CameraModule:SetDampening(posHz: number, rotHz: number)
	self.dampeningController:SetFrequencies(posHz, rotHz)
	CameraConfig.dampening.positionFrequency = posHz
	CameraConfig.dampening.rotationFrequency = rotHz
end

function CameraModule:SetDampeningEnabled(enabled: boolean)
	CameraConfig.dampening.enabled = enabled
end

function CameraModule:SetZoomBounds(min: number, max: number)
	self.zoomController:SetBounds(min, max)
end

function CameraModule:SetZoom(studs: number)
	self.zoomController:SetZoomParameters(studs, 0)
	self.zoomController:ReleaseSpring()
end

function CameraModule:SetMouseLocked(locked: boolean)
	self.mouseLockController:ForceMouseLock(locked)
end

function CameraModule:IsMouseLocked(): boolean
	return self.mouseLockController:IsMouseLocked()
end

function CameraModule:SetCrosshairEnabled(enabled: boolean)
	self.crosshairController:Enable(enabled)
end

function CameraModule:SetCrosshairImage(assetId: string)
	self.crosshairController:SetImage(assetId)
end

function CameraModule:SetCrosshairColor(color: Color3)
	self.crosshairController:SetColor(color)
end

function CameraModule:SetCrosshairSize(size: UDim2)
	self.crosshairController:SetSize(size)
end

CameraModule.new()

return {}
