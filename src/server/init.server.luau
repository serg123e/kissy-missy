-- Server entry point
-- Kissy Missy's Castle: Tag/Chase game

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService.Server

-- Services
local RemoteService = require(Server.Services.RemoteService)
local PlayerService = require(Server.Services.PlayerService)
local PrisonService = require(Server.Services.PrisonService)
local RoundService = require(Server.Services.RoundService)
local KissyService = require(Server.Services.KissyService)

-- Initialize (order matters)
RemoteService:Init()
PlayerService:Init(RemoteService)
KissyService:Init(PlayerService)
RoundService:Init(RemoteService, PlayerService, PrisonService, KissyService)
PrisonService:Init(RemoteService, PlayerService, RoundService)

-- Wire up: when a player is captured, teleport them to prison
PlayerService:SetOnCapture(function(player)
	PrisonService:TeleportToPrison(player)
end)

-- Start the game loop
RoundService:Start()

print("[Server] Kissy Missy's Castle is running")
