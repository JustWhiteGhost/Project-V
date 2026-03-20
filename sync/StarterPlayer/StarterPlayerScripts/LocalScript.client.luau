local UserInputService = game:GetService("UserInputService")
local PlayerModule = require(game.Players.LocalPlayer.PlayerScripts:WaitForChild("PlayerModule"))
local camera = PlayerModule:GetCameras()
print("camera:", camera)

local forcedFirstPerson = false

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.T then
		camera:AddCameraShake(1)
	elseif input.KeyCode == Enum.KeyCode.Y then
		local currentCamera = workspace.CurrentCamera
		if not currentCamera then
			return
		end

		local explosionPosition = currentCamera.CFrame.Position + (currentCamera.CFrame.LookVector * 2)
		camera:AddExplosionShake(
			explosionPosition,
			0.8,
			80,
			0.9,
			"debug_massive_explosion",
			18,
			1.8
		)
	elseif input.KeyCode == Enum.KeyCode.F then
		forcedFirstPerson = not forcedFirstPerson
		camera:SetFirstPersonEnabled(forcedFirstPerson)
	end
end)