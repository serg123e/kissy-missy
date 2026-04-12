-- Client entry point
-- Kissy Missy's Castle: Tag/Chase game

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local player = Players.LocalPlayer

print("[Client] Kissy Missy's Castle loaded for " .. player.Name)
