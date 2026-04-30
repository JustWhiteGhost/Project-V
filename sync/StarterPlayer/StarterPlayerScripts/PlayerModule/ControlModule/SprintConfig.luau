--!strict
-- SprintConfig - Shared configuration for sprint speed, stamina, and input mapping.

export type SprintConfigType = {
	baseWalkSpeed: number,
	speedMultiplier: number,
	maxStamina: number,
	staminaDrainPerSecond: number,
	staminaRecoveryPerSecond: number,
	keyboardSprintKey: Enum.KeyCode,
	gamepadSprintKey: Enum.KeyCode,
	keyboardActionName: string,
	gamepadActionName: string,
}

local SprintConfig: SprintConfigType = {
	baseWalkSpeed = 16,
	speedMultiplier = 2,
	maxStamina = 100,
	staminaDrainPerSecond = 0,
	staminaRecoveryPerSecond = 15,
	keyboardSprintKey = Enum.KeyCode.LeftShift,
	gamepadSprintKey = Enum.KeyCode.ButtonL3,
	keyboardActionName = "SprintKeyboard",
	gamepadActionName = "SprintGamepad",
}

return SprintConfig
