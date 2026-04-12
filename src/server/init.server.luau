-- Server entry point
-- Kissy Missy's Castle: Tag/Chase game

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService.Server

-- Services (order matters: RemoteService first, then PlayerService, then RoundService)
local RemoteService = require(Server.Services.RemoteService)
local PlayerService = require(Server.Services.PlayerService)
local RoundService = require(Server.Services.RoundService)

-- Initialize
RemoteService:Init()
PlayerService:Init(RemoteService)
RoundService:Init(RemoteService, PlayerService)

-- Start the game loop
RoundService:Start()

print("[Server] Kissy Missy's Castle is running")
