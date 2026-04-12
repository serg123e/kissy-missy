-- Creates all RemoteEvents at server start
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEventNames = require(ReplicatedStorage.Shared.Config.RemoteEvents)

local RemoteService = {}

local remotesFolder: Folder

function RemoteService:Init()
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage

	for _, name in RemoteEventNames do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotesFolder
	end

	print("[RemoteService] Created", #remotesFolder:GetChildren(), "remote events")
end

function RemoteService:Get(name: string): RemoteEvent
	return remotesFolder:FindFirstChild(name) :: RemoteEvent
end

function RemoteService:FireAll(name: string, ...: any)
	local remote = self:Get(name)
	if remote then
		remote:FireAllClients(...)
	end
end

function RemoteService:FireClient(player: Player, name: string, ...: any)
	local remote = self:Get(name)
	if remote then
		remote:FireClient(player, ...)
	end
end

return RemoteService
