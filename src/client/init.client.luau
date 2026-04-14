-- Client entry point
-- Kissy Missy's Castle: Tag/Chase game

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEventNames = require(ReplicatedStorage.Shared.Config.RemoteEvents)

-- Controllers
local InputController = require(script.Controllers.InputController)
local KissySmoothingController = require(script.Controllers.KissySmoothingController)
local HudController = require(script.UI.HudController)

-- Initialize
InputController:Init()
KissySmoothingController:Init()
HudController:Init()

-- Connect remote events to HUD
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local function listen(name: string, handler: (...any) -> ())
	local remote = remotes:WaitForChild(name)
	remote.OnClientEvent:Connect(handler)
end

listen(RemoteEventNames.GameStateChanged, function(state, timeRemaining)
	HudController:UpdateGameState(state, timeRemaining)
end)

listen(RemoteEventNames.CoinsUpdated, function(total)
	HudController:UpdateCoins(total)
end)

listen(RemoteEventNames.PlayerCaptured, function(userId)
	HudController:OnPlayerCaptured(userId)
end)

listen(RemoteEventNames.PlayerFreed, function(userId)
	HudController:OnPlayerFreed(userId)
end)

listen(RemoteEventNames.DoorStateChanged, function(isOpen)
	HudController:OnDoorStateChanged(isOpen)
end)

listen(RemoteEventNames.QueueStateChanged, function(data)
	HudController:OnQueueStateChanged(data)
end)

print("[Client] Kissy Missy's Castle loaded")
