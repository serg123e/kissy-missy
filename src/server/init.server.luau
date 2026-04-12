-- Server entry point
-- Kissy Missy's Castle: Tag/Chase game

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

print("[Server] Kissy Missy's Castle loaded")
print("[Server] Waiting for players...")
