--!strict

local CameraConfig = require(script.Parent.CameraConfig)
local CameraState = require(script.Parent.CameraState)

local OffsetController = {}
OffsetController.__index = OffsetController
export type OffsetController = typeof(setmetatable({} :: { _layers: { [string]: Vector3 } }, OffsetController))

function OffsetController.new()
	local self = setmetatable({}, OffsetController)
	self._layers = {
		base = CameraConfig.offset.defaultOffset,
		mouselock = CameraConfig.offset.mouseLockOffset,
		aim = CameraConfig.offset.aimOffset,
	}
	self:RecalculateTotalOffset()
	return self
end

function OffsetController:Update(isMouseLocked: boolean)
	self._layers.base = if isMouseLocked then CameraConfig.offset.mouseLockOffset else CameraConfig.offset.defaultOffset
	self._layers.mouselock = if isMouseLocked then CameraConfig.offset.mouseLockOffset else Vector3.zero
	self:RecalculateTotalOffset()
end

function OffsetController:GetTotalOffset(): Vector3
	return CameraState.offset.total
end

function OffsetController:SetOffset(name: string, offset: Vector3)
	self._layers[name] = offset
end

function OffsetController:ClearOffset(name: string)
	if self._layers[name] then
		self._layers[name] = nil
		self:RecalculateTotalOffset()
	end
end

function OffsetController:RecalculateTotalOffset()
	local totalOffset = Vector3.zero
	for _, offset in pairs(self._layers) do
		totalOffset += offset
	end
	CameraState.offset.total = totalOffset
end

return OffsetController
