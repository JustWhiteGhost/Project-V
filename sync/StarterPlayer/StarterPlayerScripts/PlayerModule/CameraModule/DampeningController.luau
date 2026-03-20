local CameraConfig = require(script.Parent.CameraConfig)
local CameraState = require(script.Parent.CameraState)
local CameraUtils = require(script.Parent.CameraUtils)

local DampeningController = {}
DampeningController.__index = DampeningController
export type DampeningController = typeof(setmetatable(
    {} :: {
        _positionSpring: CameraUtils.Spring,
        _rotationSpring: CameraUtils.Spring,
        _lastLookVector: Vector3,
        _lastRawLookVector: Vector3,
    },
	{} :: typeof(DampeningController)
))

function DampeningController.new()
	local self = setmetatable({}, DampeningController)
	self._positionSpring = CameraUtils.Spring.new(CameraConfig.dampening.positionFrequency, Vector3.zero)
	self._rotationSpring = CameraUtils.Spring.new(CameraConfig.dampening.rotationFrequency, Vector3.zero)
    self._lastLookVector = Vector3.new(0, 0, -1)
    self._lastRawLookVector = Vector3.new(0, 0, -1)
	return self
end

function DampeningController:SetFrequency(positionFreq: number, rotationFreq: number)
    self._positionSpring.freq = math.clamp(positionFreq, 0.1, 20)
    self._rotationSpring.freq = math.clamp(rotationFreq, 0.1, 20)
end

function DampeningController:SetFrequencies(positionFreq: number, rotationFreq: number)
    self:SetFrequency(positionFreq, rotationFreq)
end

function DampeningController:Reset()
    local rawPosition = CameraState.raw.cameraPosition or Vector3.zero
    local rawLook = CameraState.raw.lookVector or Vector3.new(0, 0, -1)

    self._positionSpring.pos = rawPosition
    self._positionSpring.vel = Vector3.zero
    self._positionSpring.goal = rawPosition

    self._rotationSpring.pos = 0
    self._rotationSpring.vel = 0
    self._rotationSpring.goal = 0

    self._lastLookVector = rawLook
    self._lastRawLookVector = rawLook
end

function DampeningController:Update(dt: number): (Vector3, Vector3)
    local rawPosition = CameraState.raw.cameraPosition
    local rawLook = CameraState.raw.lookVector

    if not rawPosition or not rawLook then
        CameraState.dampened.cameraPosition = rawPosition or Vector3.zero
        CameraState.dampened.lookVector = rawLook or Vector3.new(0, 0, -1)
        return CameraState.dampened.cameraPosition, CameraState.dampened.lookVector
    end

    if not CameraConfig.dampening.enabled then
        self:Reset()
        CameraState.dampened.cameraPosition = rawPosition
        CameraState.dampened.lookVector = rawLook
        return rawPosition, rawLook
    end

    -- Keep dt bounded so occasional frame spikes do not produce visible jumps.
    local stepDt = math.clamp(dt, 0, 1 / 20)

    self._lastRawLookVector = rawLook

    self._positionSpring.goal = rawPosition
    local dampedPosition = self._positionSpring:step(stepDt)

    -- Exponential look-vector smoothing is stable at small angles and avoids axis jitter.
    local rotationHz = math.max(self._rotationSpring.freq, 0)
    local lookAlpha = 1 - math.exp(-2 * math.pi * rotationHz * stepDt)
    local blendedLook = self._lastLookVector:Lerp(rawLook, lookAlpha)
    local dampedLook = if blendedLook.Magnitude > 1e-6 then blendedLook.Unit else rawLook
    self._lastLookVector = dampedLook

    CameraState.dampened.cameraPosition = dampedPosition
    CameraState.dampened.lookVector = dampedLook

    return dampedPosition, dampedLook
end

return DampeningController
