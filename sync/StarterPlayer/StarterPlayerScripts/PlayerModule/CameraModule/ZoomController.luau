local CameraConfig = require(script.Parent.CameraConfig)
local CameraState = require(script.Parent.CameraState)
local Popper = require(script.Popper)

local Players = game:GetService("Players")

local ZOOM_STIFFNESS = 10
local ZOOM_ACCELERATION = 100
local MIN_FOCUS_DISTANCE = 0.1
local DIST_OPAQUE = 0.5

local clamp = math.clamp
local max = math.max
local min = math.min
local pi = math.pi
local exp = math.exp

local ConstrianedSpring = {} do
	ConstrianedSpring.__index = ConstrianedSpring

	function ConstrianedSpring.new(freq: number, x: number, minValue: number, maxValue: number)
		x = clamp(x, minValue, maxValue)
		return setmetatable({
			freq = freq,
			goal = x,
			pos = x,
			vel = 0,
			minValue = minValue,
			maxValue = maxValue,
		}, ConstrianedSpring)
	end

	function ConstrianedSpring:Step(dt: number)
		local freq = self.freq * 2 * pi
		local x: number = self.x
		local v: number = self.vel
		local minValue: number = self.minValue
		local maxValue: number = self.maxValue
		local goal: number = self.goal

		local offset = goal - x
		local step = freq * dt
		local decay = exp(-step)

		local x1 = goal + (v * dt - offset * (step + 1)) * decay
		local v1 = ((offset * freq - v) * step + v) * decay

		if x1 < minValue then
			x1 = minValue
			v1 = 0
		elseif x1 > maxValue then
			x1 = maxValue
			v1 = 0
		end

		self.x = x1
		self.vel = v1

		return x1
	end
end

local function stepTargetZoom(z: number, dz: number, zoomMin: number, zoomMax: number)
	z = clamp(z + dz * (1 + z * ZOOM_ACCELERATION), zoomMin, zoomMax)
	if z < DIST_OPAQUE then
		z = dz <= 0 and zoomMin or DIST_OPAQUE
	end
	return z
end
local ZoomController = {} do
	ZoomController.__index = ZoomController

export type ZoomController = typeof(setmetatable({} :: {
	_spring: typeof(ConstrianedSpring.new(0, 0, 0, 0)),
	_zoomDelta: number,
	_inFirstPerson: boolean,
	_cameraMinZoom: number,
	_cameraMaxZoom: number,
	firstpersonChanged: BindableEvent,
}, {} :: ZoomController))

function ZoomController.new()
	local self  = setmetatable({}, ZoomController)

	self._CameraMinZoom = Players.LocalPlayer.CameraMinZoomDistance
	self._CameraMaxZoom = Players.LocalPlayer.CameraMaxZoomDistance
	self._zoomDelta = 0
	self._inFirstPerson = false

	self._sprint = ConstrianedSpring.new(ZOOM_STIFFNESS, CameraConfig.zoom.defaultZoom, MIN_FOCUS_DISTANCE, self._CameraMaxZoom)
	self.firstpersonChanged = Instance.new("BindableEvent")

	Players.LocalPlayer:GetPropertyChangedSignal("CameraMinZoomDistance"):Connect(function(...) 
		self._CameraMinZoom = Players.LocalPlayer.CameraMinZoomDistance
	end)
	Players.LocalPlayer:GetPropertyChangedSignal("CameraMaxZoomDistance"):Connect(function(...) 
		self._CameraMaxZoom = Players.LocalPlayer.CameraMaxZoomDistance
	end)
	CameraState.zoom.currentZoom = CameraConfig.zoom.defaultZoom
	CameraState.zoom.target = CameraConfig.zoom.defaultZoom 
	CameraState.zoom.inFirstPerson = false

	return self
end

function ZoomController:SetZoomParameters(targetZoom:number,  delta: number)
	self._sprint.goal = targetZoom
	self._zoomDelta = delta
	CameraState.zoom.target = targetZoom
end

function ZoomController:GetZoomRadius(): number
	return self._spring.x
end

function ZoomController:SetBounds(minZoom: number, maxZoom: number)
	self._spring.minValue = minZoom
	self._spring.maxValue = maxZoom
	self._cameraMinZoom = minZoom
	self._cameraMaxZoom = maxZoom
	self._spring.x = clamp(self._spring.x, minZoom, maxZoom)
	self._spring.goal = clamp(self._spring.goal, minZoom, maxZoom)
end



end