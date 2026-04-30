--!nonstrict
--[[
	SprintController - Tracks sprint input, stamina, and sprint speed multiplier.
]]

local ContextActionService = game:GetService("ContextActionService")

local BaseCharacterController = require(script.Parent:WaitForChild("BaseCharacterController"))
local SprintConfig = require(script:WaitForChild("SprintConfig"))

local SprintController = {}
SprintController.__index = SprintController
setmetatable(SprintController, { __index = BaseCharacterController })

function SprintController.new(priority: number)
	local self = setmetatable(BaseCharacterController.new(), SprintController)
	self.CONTROL_ACTION_PRIORITY = priority
	self.currentStamina = SprintConfig.maxStamina
	self.isSprintPressed = false
	self.isSprintActive = false
	self._keyboardHeld = false
	self._gamepadHeld = false
	self._inputCount = 0
	return self
end

local function updateInputCount(self, keyboardHeld: boolean?, gamepadHeld: boolean?)
	if keyboardHeld ~= nil then
		self._keyboardHeld = keyboardHeld
	end
	if gamepadHeld ~= nil then
		self._gamepadHeld = gamepadHeld
	end
	self._inputCount = (self._keyboardHeld and 1 or 0) + (self._gamepadHeld and 1 or 0)
	self.isSprintPressed = self._inputCount > 0
end

function SprintController:BindInputs()
	local handleKeyboardSprint = function(_actionName, inputState)
		updateInputCount(self, inputState == Enum.UserInputState.Begin, nil)
		return Enum.ContextActionResult.Pass
	end

	local handleGamepadSprint = function(_actionName, inputState)
		updateInputCount(self, nil, inputState == Enum.UserInputState.Begin)
		return Enum.ContextActionResult.Pass
	end

	ContextActionService:BindActionAtPriority(
		SprintConfig.keyboardActionName,
		handleKeyboardSprint,
		false,
		self.CONTROL_ACTION_PRIORITY,
		SprintConfig.keyboardSprintKey
	)

	ContextActionService:BindActionAtPriority(
		SprintConfig.gamepadActionName,
		handleGamepadSprint,
		false,
		self.CONTROL_ACTION_PRIORITY,
		SprintConfig.gamepadSprintKey
	)
end

function SprintController:UnbindInputs()
	ContextActionService:UnbindAction(SprintConfig.keyboardActionName)
	ContextActionService:UnbindAction(SprintConfig.gamepadActionName)
	updateInputCount(self, false, false)
end

function SprintController:Enable(enable: boolean): boolean
	if enable == self.enabled then
		return true
	end

	if enable then
		self.currentStamina = math.clamp(self.currentStamina, 0, SprintConfig.maxStamina)
		self:BindInputs()
	else
		self:UnbindInputs()
		self.isSprintActive = false
	end

	self.enabled = enable
	return true
end

function SprintController:Update(dt: number)
	if not self.enabled then
		return
	end

	local staminaDrain = SprintConfig.staminaDrainPerSecond * dt
	local staminaRecovery = SprintConfig.staminaRecoveryPerSecond * dt

	if self.isSprintPressed and self.currentStamina > 0 then
		self.isSprintActive = true
		self.currentStamina = math.max(0, self.currentStamina - staminaDrain)
		if self.currentStamina <= 0 then
			self.isSprintActive = false
		end
	else
		self.isSprintActive = false
		self.currentStamina = math.min(SprintConfig.maxStamina, self.currentStamina + staminaRecovery)
	end
end

function SprintController:GetSprintMultiplier(): number
	if self.isSprintActive then
		return math.max(1, SprintConfig.speedMultiplier)
	end
	return 1
end

function SprintController:GetStaminaPercent(): number
	if SprintConfig.maxStamina <= 0 then
		return 0
	end
	return math.clamp(self.currentStamina / SprintConfig.maxStamina, 0, 1)
end

function SprintController:SetSprintSpeed(multiplier: number)
	SprintConfig.speedMultiplier = math.max(1, multiplier)
end

function SprintController:SetStaminaConfig(maxStamina: number, drainPerSecond: number, recoveryPerSecond: number)
	SprintConfig.maxStamina = math.max(1, maxStamina)
	SprintConfig.staminaDrainPerSecond = math.max(0, drainPerSecond)
	SprintConfig.staminaRecoveryPerSecond = math.max(0, recoveryPerSecond)
	self.currentStamina = math.min(self.currentStamina, SprintConfig.maxStamina)
end

function SprintController:SetSprintInput(keyboardKey: Enum.KeyCode?, gamepadKey: Enum.KeyCode?)
	if keyboardKey then
		SprintConfig.keyboardSprintKey = keyboardKey
	end
	if gamepadKey then
		SprintConfig.gamepadSprintKey = gamepadKey
	end
	if self.enabled then
		self:UnbindInputs()
		self:BindInputs()
	end
end

return SprintController
