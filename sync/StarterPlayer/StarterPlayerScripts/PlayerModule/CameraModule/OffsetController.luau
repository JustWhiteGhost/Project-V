--!strict

local CameraConfig = require(script.Parent.CameraConfig)
local CameraState = require(script.Parent.CameraState)

local OffsetController = {}
OffsetController.__index = OffsetController
export type OffsetController = typeof(setmetatable({} :: {
	_layers: { [string]: Vector3 },
	_targetOffset: Vector3,
	_smoothedOffset: Vector3,
	_enabled: boolean,
}, OffsetController))

function OffsetController.new()
	local self = setmetatable({}, OffsetController)
	self._layers = {
		base = CameraConfig.offset.defaultOffset,
		mouselock = Vector3.zero,
		aim = Vector3.zero,
	}
	self._targetOffset = CameraConfig.offset.defaultOffset
	self._smoothedOffset = CameraConfig.offset.defaultOffset
	self._enabled = CameraConfig.offset.enabled
	self:RecalculateTotalOffset()
	return self
end

function OffsetController:Update(isMouseLocked: boolean)
	self._layers.base = if isMouseLocked then CameraConfig.offset.mouseLockOffset else CameraConfig.offset.defaultOffset
	self._layers.mouselock = if isMouseLocked then CameraConfig.offset.mouseLockOffset else Vector3.zero
	self:RecalculateTarget()
end

function OffsetController:SmoothUpdate(dt: number)
	if not self._enabled then
		CameraState.offset.total = Vector3.zero
		return
	end
	local freq = math.max(CameraConfig.offset.smoothTransitionFreq, 0.1)
	local alpha = 1 - math.exp(-2 * math.pi * freq * dt)
	self._smoothedOffset = self._smoothedOffset:Lerp(self._targetOffset, alpha)
	CameraState.offset.total = self._smoothedOffset
end

function OffsetController:GetTotalOffset(): Vector3
	return CameraState.offset.total
end

function OffsetController:SetOffset(name: string, offset: Vector3)
	self._layers[name] = offset
	self:RecalculateTarget()
end

function OffsetController:ClearOffset(name: string)
	if self._layers[name] then
		self._layers[name] = nil
		self:RecalculateTarget()
	end
end

function OffsetController:RecalculateTarget()
	local targetOffset = Vector3.zero
	for _, offset in pairs(self._layers) do
		targetOffset += offset
	end
	self._targetOffset = targetOffset
end

function OffsetController:RecalculateTotalOffset()
	local totalOffset = Vector3.zero
	for _, offset in pairs(self._layers) do
		totalOffset += offset
	end
	CameraState.offset.total = totalOffset
end

function OffsetController:SetEnabled(enabled: boolean)
	self._enabled = enabled
	if not enabled then
		self._smoothedOffset = Vector3.zero
		CameraState.offset.total = Vector3.zero
	else
		self._smoothedOffset = self._targetOffset
	end
end

function OffsetController:IsEnabled(): boolean
	return self._enabled
end

return OffsetController
