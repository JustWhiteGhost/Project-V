local ComeraConfig = require(script.Parent.CameraConfig)
local CameraState = require(script.Parent.CameraState)

local ShakeController = {}
ShakeController.__index = ShakeController
export type ShakeController = typeof(setmetatable({} :: {
    _layers: {[string]: {
        trauma: number,
        decayRate: number,
    }},
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
    self.AddNamedShake("default", amount, nil)
end
function ShakeController:AddNamedShake(tag: string, trauma: number, decayRate: number?)
    local existing = self._layers[tag]
    if existing then
        existing.trauma = math.clamp(existing.trauma + trauma, 0, 1)
    else
        self._layers[tag] = {
            trauma = math.clamp(trauma, 0, 1),
            decayRate = decayRate or ComeraConfig.shake.decay,
        }
    end
end
function ShakeController:CancelAll()
    table.clear(self._layers)
end

function ShakeController:_getTotalTrauma()
    local totalTrauma = 0
    for _, layer in pairs(self._layers) do
        totalTrauma += layer.trauma
    end
    return math.clamp(totalTrauma, 0, 1)
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

    CameraState.shake.trauma = shakeAmount

    if shakeAmount < 1e-6 then
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
    )

    local rotation = Vector3.new(
        math.noise(self._seedRx, t) * maxAngle * shakeAmount,
        math.noise(self._seedRy, t) * maxAngle * shakeAmount,
        math.noise(self._seedRz, t) * maxAngle * shakeAmount
    )

    CameraState.shake.rotation = rotation
    CameraState.shake.offset = offset
    return offset, rotation

end
return ShakeController
