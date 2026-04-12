-- Handles player input: Y key to interact with prison door
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local RemoteEventNames = require(ReplicatedStorage.Shared.Config.RemoteEvents)

local InputController = {}

local remotes: Folder

function InputController:Init()
	remotes = ReplicatedStorage:WaitForChild("Remotes")

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == GameConfig.PRISON_DOOR_INTERACT_KEY then
			self:_onDoorInteract()
		end
	end)

	print("[InputController] Initialized")
end

function InputController:_onDoorInteract()
	local remote = remotes:FindFirstChild(RemoteEventNames.DoorInteract)
	if remote then
		remote:FireServer()
	end
end

return InputController
