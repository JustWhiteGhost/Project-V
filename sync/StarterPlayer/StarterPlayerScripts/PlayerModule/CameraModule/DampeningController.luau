local CameraConfig = require(script.Parent.CameraConfig)
local CameraState = require(script.Parent.CameraState)
local CameraUtils = require(script.Parent.CameraUtils)

local DampeningController = {}
DampeningController.__index = DampeningController
export type DampeningController = typeof(setmetatable(
	{} :: { _positionspring: CameraUtils.Spring, _rotationSpring: CameraUtils.Spring, _lookRotation: Vector3 },
	{} :: typeof(DampeningController)
))

function DampeningController.new()
	local self = setmetatable({}, DampeningController)
	self._positionSpring = CameraUtils.Spring.new(CameraConfig.dampening.positionFrequency, Vector3.zero)
	self._rotationSpring = CameraUtils.Spring.new(CameraConfig.dampening.rotationFrequency, Vector3.zero)
	self._lookRotation = Vector3.new(0, 0, -1)
	return self
end

function DampeningController:SetFrequency(positionFreq: number, rotationFreq: number)
	self._positionSpring.freq = positionFreq
	self._rotationSpring.freq = rotationFreq
end

function DampeningController:Reset()
    self._positionSpring.pos = CameraState.raw.cameraPosition
    self._positionSpring.vel = Vector3.zero
    self._positionSpring.goal = CameraState.raw.cameraPosition

    self._rotationSpring.pos = 0
    self._rotationSpring.vel = 0
    self._rotationSpring.goal = 0

    self._lookRotation = CameraState.raw.lookVector
end

function DampeningController:Update(dt: number)
    if not CameraConfig.dampening.enabled then
        CameraState.dampened.cameraPosition = CameraState.raw.cameraPosition
        CameraState.dampened.lookVector = CameraState.raw.lookVector
        return CameraState.raw.cameraPosition, CameraState.raw.lookVector
    end
    self._positionSpring.pos = CameraState.raw.cameraPosition
    local dampenedPosition = self._positionSpring:step(dt)

    local dampenedLook = CameraUtils.springToLookVector(self._rotationSpring, self._lookRotation, CameraState.raw.lookVector, dt)
    self._lookRotation = dampenedLook

    CameraState.dampened.cameraPosition = dampenedPosition
    CameraState.dampened.lookVector = dampenedLook

    return dampenedPosition, dampenedLook
end

return DampeningController
