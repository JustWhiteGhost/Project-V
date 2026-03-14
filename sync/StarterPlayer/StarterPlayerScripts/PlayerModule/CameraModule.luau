local CameraModule = {}
CameraModule.__index = CameraModule

-- NOTICE: Player property names do not all match their StarterPlayer equivalents,
-- with the differences noted in the comments on the right
local PLAYER_CAMERA_PROPERTIES =
{
	"CameraMinZoomDistance",
	"CameraMaxZoomDistance",
	"CameraMode",
	"DevCameraOcclusionMode",
	"DevComputerCameraMode",			-- Corresponds to StarterPlayer.DevComputerCameraMovementMode
	"DevTouchCameraMode",				-- Corresponds to StarterPlayer.DevTouchCameraMovementMode

	-- Character movement mode
	"DevComputerMovementMode",
	"DevTouchMovementMode",
	"DevEnableMouseLock",				-- Corresponds to StarterPlayer.EnableMouseLockOption
}

local USER_GAME_SETTINGS_PROPERTIES =
{
	"ComputerCameraMovementMode",
	"ComputerMovementMode",
	"ControlMode",
	"GamepadCameraSensitivity",
	"MouseSensitivity",
	"RotationType",
	"TouchCameraMovementMode",
	"TouchMovementMode",
}

--[[ Roblox Services ]]--
local Players = game:GetService("Players")

local CommonUtils = script.Parent:WaitForChild("CommonUtils")
local ConnectionUtil = require(CommonUtils:WaitForChild("ConnectionUtil"))
local FlagUtil = require(CommonUtils:WaitForChild("FlagUtil"))

-- Static camera utils
local CameraInput = require(script:WaitForChild("CameraInput"))
local CameraUtils = require(script:WaitForChild("CameraUtils"))
local CameraUI = require(script:WaitForChild("CameraUI"))
local CameraToggleStateController = require(script:WaitForChild("CameraToggleStateController"))

local TransparencyController = require(script:WaitForChild("TransparencyController"))

-- NewSystem Requires
local GenericCamera = require(script:WaitForChild("GenericCamera"))

-- Load Roblox Occlusion Modules
local Invisicam = require(script:WaitForChild("Invisicam"))
local Poppercam = require(script:WaitForChild("Poppercam"))

if not Players.LocalPlayer then
	return {}
end
assert(Players.LocalPlayer, "Strict typing check")

-- Management of which options appear on the Roblox User Settings screen
do
	local PlayerScripts: PlayerScripts = Players.LocalPlayer:WaitForChild("PlayerScripts") :: PlayerScripts

	PlayerScripts:RegisterTouchCameraMovementMode(Enum.TouchCameraMovementMode.Default)
	PlayerScripts:RegisterTouchCameraMovementMode(Enum.TouchCameraMovementMode.Follow)
	PlayerScripts:RegisterTouchCameraMovementMode(Enum.TouchCameraMovementMode.Classic)

	PlayerScripts:RegisterComputerCameraMovementMode(Enum.ComputerCameraMovementMode.Default)
end

local FFlagUserPlayerConnectionMemoryLeak = FlagUtil.getUserFlag("UserPlayerConnectionMemoryLeak")

-- Change this later as types are added for more classes
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
}

export type CameraModule = typeof(setmetatable({} :: {
	activeCameraController: GenericOptional,
	activeMouseLockController: GenericOptional,
	activeOcclusionModule: GenericOptional,
	activeTransparencyController: Generic,
	cameraSubjectChangedConn: RBXScriptConnection?,
	cameraTypeChangedConn: RBXScriptConnection?,
	connectionUtil: ConnectionUtil.ConnectionUtil?,
	currentComputerCameraMovementMode: Enum.ComputerCameraMovementMode? | Enum.DevComputerCameraMovementMode?,
	occlusionMode: Enum.DevCameraOcclusionMode?,
}, {} :: CameraModuleClass))

function CameraModule.new()
	local self: CameraModule = setmetatable({},CameraModule)

	self.activeCameraController = nil
	self.activeTransparencyController = nil
	self.activeOcclusionModule = nil
	self.connectionUtil = nil
	self.activeOcclusionModule = nil
	self.activeMouseLockController = nil
	self.currentComputerCameraMovementMode = nil
	self.cameraSubjectChangedConn = nil
	self.cameraTypeChangedConn = nil

	-- New Systems
	return self
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

	-- First check to see if there is actually a change. If the module being requested is already
	-- the currently-active solution then just make sure it's enabled and exit early
	if self.activeOcclusionModule and self.activeOcclusionModule:GetOcclusionMode() == occlusionMode then
		if not self.activeOcclusionModule:GetEnabled() then
			self.activeOcclusionModule:Enable(true)
		end
		return
	end

	-- Save a reference to the current active module (may be nil) so that we can disable it if
	-- we are successful in activating its replacement
	local prevOcclusionModule = self.activeOcclusionModule

	-- If there is no active module, see if the one we need has already been instantiated
	self.activeOcclusionModule = instantiatedOcclusionModules[newModuleCreator]

	-- If the module was not already instantiated and selected above, instantiate it
	if not self.activeOcclusionModule then
		self.activeOcclusionModule = newModuleCreator.new()
		if self.activeOcclusionModule then
			instantiatedOcclusionModules[newModuleCreator] = self.activeOcclusionModule
		end
	end

	-- If we were successful in either selecting or instantiating the module,
	-- enable it if it's not already the currently-active enabled module
	if self.activeOcclusionModule then
		local newModuleOcclusionMode = self.activeOcclusionModule:GetOcclusionMode()
		-- Sanity check that the module we selected or instantiated actually supports the desired occlusionMode
		if newModuleOcclusionMode ~= occlusionMode then
			warn("CameraScript ActivateOcclusionModule mismatch: ",self.activeOcclusionModule:GetOcclusionMode(),"~=",occlusionMode)
		end

		-- Deactivate current module if there is one
		if prevOcclusionModule then
			-- Sanity check that current module is not being replaced by itself (that should have been handled above)
			if prevOcclusionModule ~= self.activeOcclusionModule then
				prevOcclusionModule:Enable(false)
			else
				warn("CameraScript ActivateOcclusionModule failure to detect already running correct module")
			end
		end

		-- Occlusion modules need to be initialized with information about characters and cameraSubject
		-- Invisicam needs the LocalPlayer's character
		-- Poppercam needs all player characters and the camera subject
		if occlusionMode == Enum.DevCameraOcclusionMode.Invisicam then
			-- Optimization to only send Invisicam what we know it needs
			if Players.LocalPlayer.Character then
				self.activeOcclusionModule:CharacterAdded(Players.LocalPlayer.Character, Players.LocalPlayer )
			end
		else
			-- When Poppercam is enabled, we send it all existing player characters for its raycast ignore list
			for _, player in pairs(Players:GetPlayers()) do
				if player and player.Character then
					self.activeOcclusionModule:CharacterAdded(player.Character, player)
				end
			end
			self.activeOcclusionModule:OnCameraSubjectChanged((game.Workspace.CurrentCamera :: Camera).CameraSubject)
		end

		-- Activate new choice
		self.activeOcclusionModule:Enable(true)
	end
end

-- Note: The active transparency controller could be made to listen for this event itself.
function CameraModule:OnCameraSubjectChanged()
	local camera = workspace.CurrentCamera
	local cameraSubject = if camera then camera.CameraSubject else nil

	if self.activeTransparencyController then
		self.activeTransparencyController:SetSubject(cameraSubject)
	end

	if self.activeOcclusionModule then
		self.activeOcclusionModule:OnCameraSubjectChanged(cameraSubject)
	end
end

-- Note: Called whenever workspace.CurrentCamera changes, but also on initialization of this script
function CameraModule:OnCurrentCameraChanged()
	local currentCamera = game.Workspace.CurrentCamera
	if not currentCamera then return end

	if self.cameraSubjectChangedConn then
		self.cameraSubjectChangedConn:Disconnect()
	end

	if self.cameraTypeChangedConn then
		self.cameraTypeChangedConn:Disconnect()
	end

	self.cameraSubjectChangedConn = currentCamera:GetPropertyChangedSignal("CameraSubject"):Connect(function()
		self:OnCameraSubjectChanged()
	end)



	self:OnCameraSubjectChanged()
end

function CameraModule:Update(dt)
	if self.activeCameraController then
		self.activeCameraController:UpdateMouseBehavior()

		local newCameraCFrame, newCameraFocus = self.activeCameraController:Update(dt)

		if self.activeOcclusionModule then
			newCameraCFrame, newCameraFocus = self.activeOcclusionModule:Update(dt, newCameraCFrame, newCameraFocus)
		end

		-- Here is where the new CFrame and Focus are set for this render frame
		local currentCamera = game.Workspace.CurrentCamera :: Camera
		currentCamera.CFrame = newCameraCFrame
		currentCamera.Focus = newCameraFocus

		-- Update to character local transparency as needed based on camera-to-subject distance
		if self.activeTransparencyController then
			self.activeTransparencyController:Update(dt)
		end

		if CameraInput.getInputEnabled() then
			CameraInput.resetInputForFrameEnd()
		end
	end
end

function CameraModule:OnCharacterAdded(char: Model, player: Player)
	if self.activeOcclusionModule then
		self.activeOcclusionModule:CharacterAdded(char, player)
	end
end

function CameraModule:OnCharacterRemoving(char, player)
	if self.activeOcclusionModule then
		self.activeOcclusionModule:CharacterRemoving(char, player)
	end
end

function CameraModule:OnPlayerAdded(player: Player)
	if FFlagUserPlayerConnectionMemoryLeak then
		-- Return connectionUtil to non optional if FFlagUserPlayerConnectionMemoryLeak is removed
		if self.connectionUtil then
			self.connectionUtil:trackConnection(`{player.UserId}CharacterAdded`, player.CharacterAdded:Connect(function(char)
				self:OnCharacterAdded(char, player)
			end))
			self.connectionUtil:trackConnection(`{player.UserId}CharacterRemoving`, player.CharacterRemoving:Connect(function(char)
				self:OnCharacterRemoving(char, player)
			end))
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
	-- Return connectionUtil to non optional if FFlagUserPlayerConnectionMemoryLeak is removed
	if self.connectionUtil then
		self.connectionUtil:disconnect(`{player.UserId}CharacterAdded`)
		self.connectionUtil:disconnect(`{player.UserId}CharacterRemoving`)
	end
end
CameraModule.new()

return {}
