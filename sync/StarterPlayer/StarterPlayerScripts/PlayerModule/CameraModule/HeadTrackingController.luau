--!nonstrict
-- HeadTrackingController
-- Rotates the character's neck and waist to follow the camera look direction.

local Players = game:GetService("Players")

local CameraConfig = require(script.Parent:WaitForChild("CameraConfig"))

local HeadTrackingController = {}
HeadTrackingController.__index = HeadTrackingController

export type HeadTrackingController = typeof(setmetatable({} :: {
	_neck: Motor6D?,
	_waist: Motor6D?,
	_neckC0: CFrame?,
	_waistC0: CFrame?,
	_isR6: boolean,
	_enabled: boolean,
	_characterAddedConn: RBXScriptConnection?,
	_characterRemovingConn: RBXScriptConnection?,
}, {} :: typeof(HeadTrackingController)))

function HeadTrackingController.new()
	local self = setmetatable({}, HeadTrackingController)

	self._neck = nil
	self._waist = nil
	self._neckC0 = nil
	self._waistC0 = nil
	self._isR6 = false
	self._enabled = CameraConfig.headTracking.enabled

	local player = Players.LocalPlayer

	local function onCharacterAdded(character: Model)
		self:_setupCharacter(character)
	end

	local function onCharacterRemoving()
		self:_clearCharacter()
	end

	self._characterAddedConn = player.CharacterAdded:Connect(onCharacterAdded)
	self._characterRemovingConn = player.CharacterRemoving:Connect(onCharacterRemoving)

	-- Handle already existing character
	if player.Character then
		self:_setupCharacter(player.Character)
	end

	return self
end

function HeadTrackingController:_setupCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	self._isR6 = humanoid.RigType == Enum.HumanoidRigType.R6

	local head = character:WaitForChild("Head") :: BasePart
	local torso = (if self._isR6
		then character:WaitForChild("Torso")
		else character:WaitForChild("UpperTorso")) :: BasePart

	local neck = (if self._isR6
		then torso:WaitForChild("Neck")
		else head:WaitForChild("Neck")) :: Motor6D

	self._neck = neck
	self._neckC0 = neck.C0

	if not self._isR6 then
		local waist = torso:WaitForChild("Waist") :: Motor6D
		self._waist = waist
		self._waistC0 = waist.C0
	else
		self._waist = nil
		self._waistC0 = nil
	end
end

function HeadTrackingController:_clearCharacter()
	-- Restore C0 values before clearing
	if self._neck and self._neckC0 then
		self._neck.C0 = self._neckC0
	end
	if self._waist and self._waistC0 then
		self._waist.C0 = self._waistC0
	end

	self._neck = nil
	self._waist = nil
	self._neckC0 = nil
	self._waistC0 = nil
end

function HeadTrackingController:Enable(enabled: boolean)
	self._enabled = enabled

	if not enabled then
		-- Restore default C0 values when disabled
		if self._neck and self._neckC0 then
			self._neck.C0 = self._neckC0
		end
		if self._waist and self._waistC0 then
			self._waist.C0 = self._waistC0
		end
	end
end

function HeadTrackingController:SetFactors(
	headHor: number,
	headVer: number,
	bodyHor: number,
	bodyVer: number
)
	CameraConfig.headTracking.headHorizontalFactor = headHor
	CameraConfig.headTracking.headVerticalFactor = headVer
	CameraConfig.headTracking.bodyHorizontalFactor = bodyHor
	CameraConfig.headTracking.bodyVerticalFactor = bodyVer
end

function HeadTrackingController:Update(dt: number, isFirstPerson: boolean)
	if not self._enabled then return end
	if isFirstPerson then return end
	if not self._neck or not self._neckC0 then return end

	local player = Players.LocalPlayer
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local camera = workspace.CurrentCamera
	local head = character:FindFirstChild("Head") :: BasePart?
	local torso = if self._isR6
		then character:FindFirstChild("Torso") :: BasePart?
		else character:FindFirstChild("UpperTorso") :: BasePart?

	if not head or not torso or not camera then return end
	if camera.CameraSubject ~= humanoid then return end

	local config = CameraConfig.headTracking
	local lerpSpeed = math.clamp(config.updateSpeed * dt * 60, 0, 1)

	local camCF = camera.CFrame
	local headCF = head.CFrame
	local torsoLV = torso.CFrame.LookVector

	local dist = (headCF.Position - camCF.Position).Magnitude
	if dist < 0.001 then return end

	local diff = headCF.Position.Y - camCF.Position.Y
	local asinDiffDist = math.asin(math.clamp(diff / dist, -1, 1))
	local crossY = ((headCF.Position - camCF.Position).Unit:Cross(torsoLV)).Y

	if self._isR6 then
		self._neck.C0 = self._neck.C0:Lerp(
			self._neckC0 * CFrame.Angles(
				-asinDiffDist * config.headVerticalFactor,
				0,
				-crossY * config.headHorizontalFactor
			),
			lerpSpeed
		)
	else
		self._neck.C0 = self._neck.C0:Lerp(
			self._neckC0 * CFrame.Angles(
				asinDiffDist * config.headVerticalFactor,
				-crossY * config.headHorizontalFactor,
				0
			),
			lerpSpeed
		)

		if self._waist and self._waistC0 then
			self._waist.C0 = self._waist.C0:Lerp(
				self._waistC0 * CFrame.Angles(
					asinDiffDist * config.bodyVerticalFactor,
					-crossY * config.bodyHorizontalFactor,
					0
				),
				lerpSpeed
			)
		end
	end
end

return HeadTrackingController