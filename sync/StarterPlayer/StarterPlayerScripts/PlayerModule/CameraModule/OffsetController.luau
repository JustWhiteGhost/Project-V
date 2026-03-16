--!strict

local CameraConfig = require(script.Parent.CameraConfig)
local CameraState = require(script.Parent.CameraState)

local _layers = {
	["base"] = Vector3.new(0, 0, 0),
	["mouselock"] = Vector3.new(0, 0, 0),
	["aim"] = Vector3.new(0, 0, 0),
}

local OffsetController = {}
OffsetController.__index = OffsetController
export type OffsetController = typeof(setmetatable({} :: { _layers: { [string]: Vector3 } }, OffsetController))

function OffsetController.new()
	local self = setmetatable({}, OffsetController)
	self.layers = {
		base = CameraConfig.offset.defaultOffset,
		mouselock = CameraConfig.offset.mouseLockOffset,
		aim = CameraConfig.offset.aimOffset,
	}
	self:RecalculateTotalOffset()
	return self
end

function OffsetController:Update(isMouseLocked: boolean)
	self._layers.base = if isMouseLocked then CameraConfig.offset.mouseLockOffset else CameraConfig.offset.defaultOffset
	self.layers.mouselock = if isMouseLocked then CameraConfig.offset.mouseLockOffset else Vector3.zero
	self:RecalculateTotalOffset()
end

function OffsetController:GetTotalOffset(): Vector3
	return CameraState.offset.total
end

function OffsetController:SetOffset(name: string, offset: Vector3)
	self.layers[name] = offset
end

function OffsetController:ClearOffset(name: string)
	if self.layers[name] then
		self.layers[name] = nil
		self:RecalculateTotalOffset()
	end
end

function OffsetController:RecalculateTotalOffset()
	local totalOffset = Vector3.zero
	for _, offset in pairs(self.layers) do
		totalOffset += offset
	end
	CameraState.offset.total = totalOffset
end

return OffsetController
