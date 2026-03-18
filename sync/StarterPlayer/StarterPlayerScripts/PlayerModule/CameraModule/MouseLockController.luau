local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")

local CameraConfig = require(script.Parent.CameraConfig)
local CameraState = require(script.Parent.CameraState)
local CameraUtils = require(script.Parent.CameraUtils)

local MOUSELOCK_ACTION = "ToggleMouseLock"
local MOUSELOCK_PRIORITY = Enum.ContextActionPriority.Medium.Value

local MouseLockController = {}
MouseLockController.__index = MouseLockController
export type MouseLockController = typeof(setmetatable({} :: {
	toggleEvent: BindableEvent,
	_isMouseLocked: boolean,
	_enabled: boolean,
	_forceMouseLock: boolean,
}, {} :: typeof(MouseLockController)))

function MouseLockController.new()
	local self = setmetatable({}, MouseLockController)
	self.toggleEvent = Instance.new("BindableEvent")
	self._isMouseLocked = false
	self._enabled = false
	self._forceMouseLock = false

	CameraState.mouseLock.isLocked = false
	CameraState.mouseLock.offset = Vector3.zero

	Players.LocalPlayer:GetPropertyChangedSignal("DevEnableMouseLock"):Connect(function()
		self:UpdateAvailablity()
	end)
	Players.LocalPlayer:GetPropertyChangedSignal("DevComputerMovementMode"):Connect(function()
		self:UpdateAvailablity()
	end)
	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
		self:UpdateAvailablity()
	end)

	local GameSettings = UserSettings():GetService("UserGameSettings")
	GameSettings.Changed:Connect(function(property) if property == "ControlMode" or property == "ComputerMovementMode"then self:UpdateAvailablity()  end end)
	self:UpdateAvailablity()
	return self
end

function MouseLockController:_BindKeys()
	ContextActionService:BindActionAtPriority(
		MOUSELOCK_ACTION,
		function(_, state, _)
			if state == Enum.UserInputState.Begin then
				self:Toggle()
			end
		end,
		false,
		MOUSELOCK_PRIORITY,
		table.unpack(CameraConfig.mouseLock.boundKeys)
	)
end

function MouseLockController:_UnbindKeys()
	ContextActionService:UnbindAction(MOUSELOCK_ACTION)
end

function MouseLockController:SetIsLocked(isLocked: boolean)
	if self._isMouseLocked == isLocked then return end
	self._isMouseLocked = isLocked
	if isLocked then
		CameraUtils.setMouseIconOverride(CameraConfig.mouseLock.cursorImage)
		CameraUtils.setMouseBehaviorOverride(Enum.MouseBehavior.LockCenter)
		CameraUtils.setRotationTypeOverride(Enum.RotationType.CameraRelative)
		CameraState.mouseLock.offset = CameraConfig.offset.mouseLockOffset
	else
		CameraUtils.restoreMouseIcon()
		CameraUtils.restoreMouseBehavior()
		CameraUtils.restoreRotationType()
		CameraState.mouseLock.offset = Vector3.zero
	end

	CameraState.mouseLock.isLocked = isLocked
	self.toggleEvent:Fire(isLocked)
end

function MouseLockController:Toggle()
	if(not self._enabled) then return end
	print("Toggling mouse lock")
	self:SetIsLocked(not self._isMouseLocked)
end

function MouseLockController:ForceMouseLock(enabled: boolean)
	self._forceMouseLock = enabled
	if self._enabled then
		self:SetIsLocked(enabled)
	end
end

function MouseLockController:UpdateAvailablity()
	local GameSettings = UserSettings():GetService("UserGameSettings")
	local Player = Players.LocalPlayer

	local devAllowsMouseLock = Player.DevEnableMouseLock
	local devMovementScriptable = Player.DevComputerMovementMode == Enum.DevComputerMovementMode.Scriptable
	local userHasClickToMove = GameSettings.ComputerMovementMode == Enum.ComputerMovementMode.ClickToMove
	local usingKeyboardAndMouse = UserInputService.PreferredInput == Enum.PreferredInput.KeyboardAndMouse

	local available = usingKeyboardAndMouse 
    and devAllowsMouseLock 
    and not devMovementScriptable 
    and not userHasClickToMove

	if available == self._enabled then return end
	self._enabled = available
	if available then
		self:_BindKeys()
		if self._forceMouseLock then
			self:SetIsLocked(true)
		end
	else
		self:_UnbindKeys()
		if self._isMouseLocked then
			self:SetIsLocked(false)
		end
	end
end

function MouseLockController:IsMouseLocked(): boolean
	return self._isMouseLocked and self._enabled
end

function MouseLockController:GetBindableToggleEvent(): RBXScriptSignal
	return self.toggleEvent.Event
end
return MouseLockController