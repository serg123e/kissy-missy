-- Handles player input: Y key for prison door, E key for treadmill queue
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local RemoteEventNames = require(ReplicatedStorage.Shared.Config.RemoteEvents)

local InputController = {}

local remotes: Folder
local player = Players.LocalPlayer

function InputController:Init()
	remotes = ReplicatedStorage:WaitForChild("Remotes")

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == GameConfig.PRISON_DOOR_INTERACT_KEY then
			self:_onDoorInteract()
		elseif input.KeyCode == GameConfig.QUEUE_JOIN_KEY then
			self:_onQueueJoin()
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

function InputController:_onQueueJoin()
	local character = player.Character
	if not character then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	local treadmillsFolder = workspace:FindFirstChild("Treadmills")
	if not treadmillsFolder then
		return
	end

	local nearest: BasePart? = nil
	local nearestDist = GameConfig.QUEUE_JOIN_RADIUS

	for _, child in treadmillsFolder:GetChildren() do
		if child:IsA("BasePart") then
			local dist = (hrp.Position - child.Position).Magnitude
			if dist < nearestDist then
				nearest = child
				nearestDist = dist
			end
		end
	end

	if nearest then
		local remote = remotes:FindFirstChild(RemoteEventNames.QueueJoin)
		if remote then
			remote:FireServer(nearest.Name)
		end
	end
end

return InputController
