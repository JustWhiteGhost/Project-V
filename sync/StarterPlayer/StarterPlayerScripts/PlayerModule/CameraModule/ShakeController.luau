local ComeraConfig = require(script.Parent.CameraConfig)
local CameraState = require(script.Parent.CameraState)

local MAX_TRAUMA = 3

local ShakeController = {}
ShakeController.__index = ShakeController
export type ShakeController = typeof(setmetatable({} :: {
    _layers: {[string]: {
        trauma: number,
        decayRate: number,
    }},
    _impulseAmplitude: Vector3,
    _impulseRotationAmplitude: Vector3,
    _impulsePhase: number,
    _impulseFrequency: number,
    _impulseOffset: Vector3,
    _impulseRotation: Vector3,
    _impulseDecayRate: number,
    _snapOffset: Vector3,
    _snapRotation: Vector3,
    _snapDecayRate: number,
    _seedX: number,
    _seedY: number,
    _seedZ: number,
    _seedRx: number,
    _seedRy: number,
    _seedRz: number,
}, {} :: typeof(ShakeController)))

function ShakeController.new()
    local self = setmetatable({}, ShakeController)
    self._layers = {}
    self._impulseAmplitude = Vector3.zero
    self._impulseRotationAmplitude = Vector3.zero
    self._impulsePhase = 0
    self._impulseFrequency = 4.5
    self._impulseOffset = Vector3.zero
    self._impulseRotation = Vector3.zero
    self._impulseDecayRate = 6
    self._snapOffset = Vector3.zero
    self._snapRotation = Vector3.zero
    self._snapDecayRate = 22
    self._seedX = math.random() * 100
    self._seedY = math.random() * 100
    self._seedZ = math.random() * 100
    self._seedRx = math.random() * 100
    self._seedRy = math.random() * 100
    self._seedRz = math.random() * 100

    CameraState.shake.trauma = 0
    CameraState.shake.rotation = Vector3.zero
    CameraState.shake.offset = Vector3.zero
    return self
end
function ShakeController:AddTrauma(amount: number)
    self:AddNamedShake("default", amount, nil)
end
function ShakeController:AddNamedShake(tag: string, trauma: number, decayRate: number?)
    local existing = self._layers[tag]
    if existing then
        existing.trauma = math.clamp(existing.trauma + trauma, 0, MAX_TRAUMA)
    else
        self._layers[tag] = {
            trauma = math.clamp(trauma, 0, MAX_TRAUMA),
            decayRate = decayRate or ComeraConfig.shake.decay,
        }
    end
end

function ShakeController:CancelShake(tag: string)
    self._layers[tag] = nil
end

function ShakeController:AddDirectionalImpulse(direction: Vector3, magnitude: number, decayRate: number?)
    if magnitude <= 0 then
        return
    end

    local dirMagnitude = direction.Magnitude
    if dirMagnitude < 1e-6 then
        return
    end

    local normalizedDirection = direction / dirMagnitude
    self._impulseAmplitude += normalizedDirection * magnitude

    local rotationalKick = Vector3.new(
        -normalizedDirection.Y,
        normalizedDirection.X,
        normalizedDirection.Z * 0.35
    ) * (magnitude * 0.05)
    self._impulseRotationAmplitude += rotationalKick

    -- Sharp initial hit before spring wobble takes over.
    self._snapOffset += normalizedDirection * (magnitude * 0.45)
    self._snapRotation += rotationalKick * 2.2

    self._impulsePhase = math.pi * 0.5

    if decayRate and decayRate > 0 then
        self._impulseDecayRate = math.clamp(decayRate, 0.5, 20)
    end
end

function ShakeController:CancelAll()
    table.clear(self._layers)
    self._impulseAmplitude = Vector3.zero
    self._impulseRotationAmplitude = Vector3.zero
    self._impulsePhase = 0
    self._impulseOffset = Vector3.zero
    self._impulseRotation = Vector3.zero
    self._snapOffset = Vector3.zero
    self._snapRotation = Vector3.zero
end

function ShakeController:_getTotalTrauma()
    local totalTrauma = 0
    for _, layer in pairs(self._layers) do
        totalTrauma += layer.trauma
    end
    return math.clamp(totalTrauma, 0, MAX_TRAUMA)
end

function ShakeController:Update(dt: number): (Vector3, Vector3)
    for tag,layer in pairs(self._layers) do
        layer.trauma = math.max(0, layer.trauma - layer.decayRate * dt)
        if layer.trauma <= 0 then
            self._layers[tag] = nil
        end
    end
    local totalTrauma = self:_getTotalTrauma()
    local shakeAmount = totalTrauma * totalTrauma

    local impulseOffset = self._impulseOffset
    local impulseAmplitude = self._impulseAmplitude
    local impulseRotation = self._impulseRotation
    local impulseRotationAmplitude = self._impulseRotationAmplitude
    local snapOffset = self._snapOffset
    local snapRotation = self._snapRotation

    if snapOffset.Magnitude > 1e-6 or snapRotation.Magnitude > 1e-6 then
        local snapDecay = math.exp(-self._snapDecayRate * dt)
        snapOffset *= snapDecay
        snapRotation *= snapDecay
        if snapOffset.Magnitude < 1e-4 then
            snapOffset = Vector3.zero
        end
        if snapRotation.Magnitude < 1e-4 then
            snapRotation = Vector3.zero
        end
        self._snapOffset = snapOffset
        self._snapRotation = snapRotation
    else
        snapOffset = Vector3.zero
        snapRotation = Vector3.zero
        self._snapOffset = Vector3.zero
        self._snapRotation = Vector3.zero
    end

    if impulseAmplitude.Magnitude > 1e-6 or impulseRotationAmplitude.Magnitude > 1e-6 then
        self._impulsePhase += dt * self._impulseFrequency * math.pi * 2
        local impulseDecay = math.exp(-self._impulseDecayRate * dt)
        impulseAmplitude *= impulseDecay
        impulseRotationAmplitude *= impulseDecay
        local oscillation = math.sin(self._impulsePhase)
        impulseOffset = impulseAmplitude * oscillation
        impulseRotation = impulseRotationAmplitude * oscillation

        if impulseAmplitude.Magnitude < 1e-4 and impulseOffset.Magnitude < 1e-4 and impulseRotationAmplitude.Magnitude < 1e-4 then
            impulseAmplitude = Vector3.zero
            impulseRotationAmplitude = Vector3.zero
            impulseOffset = Vector3.zero
            impulseRotation = Vector3.zero
            self._impulsePhase = 0
        end

        self._impulseAmplitude = impulseAmplitude
        self._impulseRotationAmplitude = impulseRotationAmplitude
        self._impulseOffset = impulseOffset
        self._impulseRotation = impulseRotation
    else
        self._impulseAmplitude = Vector3.zero
        self._impulseRotationAmplitude = Vector3.zero
        impulseOffset = Vector3.zero
        impulseRotation = Vector3.zero
        self._impulseOffset = Vector3.zero
        self._impulseRotation = Vector3.zero
    end

    CameraState.shake.trauma = shakeAmount

    if shakeAmount < 1e-6 and impulseOffset.Magnitude < 1e-6 and impulseRotation.Magnitude < 1e-6 and snapOffset.Magnitude < 1e-6 and snapRotation.Magnitude < 1e-6 then
        CameraState.shake.rotation = Vector3.zero
        CameraState.shake.offset = Vector3.zero
        return Vector3.zero, Vector3.zero
    end
    local t = tick() * ComeraConfig.shake.frequency
    local maxAngle = ComeraConfig.shake.maxAngleRandians
    local maxOffset = ComeraConfig.shake.maxOffset

    local offset = Vector3.new(
        math.noise(self._seedX, t) * maxOffset * shakeAmount,
        math.noise(self._seedY, t) * maxOffset * shakeAmount,
        math.noise(self._seedZ, t) * maxOffset * shakeAmount
    ) + impulseOffset + snapOffset

    local rotation = Vector3.new(
        math.noise(self._seedRx, t) * maxAngle * shakeAmount,
        math.noise(self._seedRy, t) * maxAngle * shakeAmount,
        math.noise(self._seedRz, t) * maxAngle * shakeAmount
    ) + impulseRotation + snapRotation

    CameraState.shake.rotation = rotation
    CameraState.shake.offset = offset
    return offset, rotation

end
return ShakeController
