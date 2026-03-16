local CameraConfig = require(script.Parent.CameraConfig)

local Players = game:GetService("Players")

local CrosshairController = {}
CrosshairController.__index = CrosshairController
export type CrosshairController = typeof(setmetatable(
	{} :: {
		_gui: ScreenGui,
		_crosshair: ImageLabel,
		_enabled: boolean,
		_visible: boolean,
	},
	{} :: typeof(CrosshairController)
))

function CrosshairController.new()
	local self = setmetatable({}, CrosshairController)

	self._currentSpread = 0
	self._enabled = CameraConfig.crosshair.enabled
	self._isFirstPerson = false
	self._isMouseLocked = false

	-- Build GUI
	local gui = Instance.new("ScreenGui")
	gui.Name = "CameraSystemCrosshair"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10

	local image = Instance.new("ImageLabel")
	image.Name = "Crosshair"
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.Size = CameraConfig.crosshair.size
	image.Image = CameraConfig.crosshair.image
	image.ImageColor3 = CameraConfig.crosshair.color
	image.BackgroundTransparency = 1
	image.Parent = gui

	self._gui = gui
	self._image = image

	-- Wait for PlayerGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui.Parent = playerGui

	self:_updateVisibility()

	return self
end

function CrosshairController:Enable(enabled: boolean)
	self._enabled = enabled
	self:_updateVisibility()
end

function CrosshairController:SetImage(assetId: string)
	self._image.Image = assetId
end

function CrosshairController:SetSize(size: UDim2)
	self._image.Size = size
	self:SetSpread(self._currentSpread)
end

function CrosshairController:SetColor(color: Color3)
	self._image.ImageColor3 = color
end

function CrosshairController:_updateVisibility()
	local visible = self._enabled

	if CameraConfig.crosshair.hideInThirdPerson and not self._isFirstPerson then
		visible = false
	end

	if self._isMouseLocked then
		visible = false
	end

	self._gui.Enabled = visible
end
function CrosshairController:Update(
	dt: number,
	isMouseLocked: boolean,
	isFirstPerson: boolean
)
	self._isMouseLocked = isMouseLocked
	self._isFirstPerson = isFirstPerson
	self:_updateVisibility()
end
return CrosshairController
