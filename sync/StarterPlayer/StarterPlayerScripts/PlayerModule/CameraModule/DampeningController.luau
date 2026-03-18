local CameraConfig = require(script.Parent.CameraConfig)
local CameraInput = require(script.Parent.CameraInput)
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

function DampeningController:Update(dt: number): (Vector3, Vector3)
    if not CameraConfig.dampening.enabled then
        CameraState.dampened.cameraPosition = CameraState.raw.cameraPosition
        CameraState.dampened.lookVector = CameraState.raw.lookVector
        return CameraState.raw.cameraPosition, CameraState.raw.lookVector
    end
    
    if not CameraState.raw.lookVector or not CameraState.raw.cameraPosition then
    CameraState.dampened.cameraPosition = CameraState.raw.cameraPosition or Vector3.zero
    CameraState.dampened.lookVector = CameraState.raw.lookVector or Vector3.new(0, 0, -1)
    return CameraState.dampened.cameraPosition, CameraState.dampened.lookVector
end
    -- snap position spring to target when actively rotating
    local rotateInput = CameraInput.getRotation(dt)
    if rotateInput.Magnitude > 0.01 then
        self._positionSpring.pos = CameraState.raw.cameraPosition
        self._positionSpring.vel = Vector3.zero
    end

    -- Step position spring
    self._positionSpring.goal = CameraState.raw.cameraPosition
    local dampedPosition = self._positionSpring:step(dt)

    -- Step rotation spring
    local dampedLook = CameraUtils.springToLookVector(
        self._rotationSpring,
        self._lastLookVector,
        CameraState.raw.lookVector,
        dt
    )
    self._lastLookVector = dampedLook

    CameraState.dampened.cameraPosition = dampedPosition
    CameraState.dampened.lookVector = dampedLook

    return dampedPosition, dampedLook
end

return DampeningController
